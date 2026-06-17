# NFS 共享存储迁移实战记录

> 本文档记录从 `local-path` 本地存储迁移到 `nfs-storage` 共享存储的全过程，
> 包括背景、架构、实施步骤、踩坑记录和验收清单。

---

## 目录

- [1. 背景与动机](#1-背景与动机)
- [2. 架构总览](#2-架构总览)
- [3. 实施步骤](#3-实施步骤)
- [4. 踩坑记录](#4-踩坑记录)
- [5. 迁移清单](#5-迁移清单)
- [6. 验收清单](#6-验收清单)
- [7. 运维说明](#7-运维说明)
- [8. FAQ](#8-faq)

---

## 1. 背景与动机

### 为什么需要 NFS？

集群使用 `local-path`（k3s 默认存储类），数据存储在节点本地的
`/var/lib/rancher/k3s/storage/`。重启电脑后：

**问题复现：**
- Pod 调度到不同节点 → 旧节点上有数据但新节点上为空 → 数据「丢了」
- kite 应用里所有数据消失（SQLite 数据库）
- 其他有状态服务同样面临此风险

**为什么不直接用 Longhorn/Rook？**
- 3 节点实验环境，数据量小（共 36Gi），NFS 足够
- NFS 配置简单（单二进制、nfs-utils 包即可）
- nfs-subdir-external-provisioner 稳定维护多年，K8s SIG-Storage 子项目

### 结论

`local-path` 适用于单节点测试或不需要持久化的场景。
多节点集群必须用共享存储。

---

## 2. 架构总览

```
┌─────────────────────────────────────────────────────────────────┐
│                       K8s Cluster                               │
│  k3s-server-1 (249)  k3s-server-2 (101)  k3s-server-3 (100)   │
│        │                     │                     │            │
│        └────────────┬────────┴────────┬────────────┘            │
│                     │                 │                         │
│              ┌──────▼─────────────────▼──────┐                  │
│              │   NFS Client (nfs-utils)      │                  │
│              │   /srv/nfs/k8s/ mounted       │                  │
│              └──────────────┬────────────────┘                  │
│                             │                                    │
│   ┌─────────────────────────▼─────────────────────────────┐     │
│   │            NFS Server (k3s-server-1)                  │     │
│   │            192.168.5.249:/srv/nfs/k8s/                │     │
│   │                                                       │     │
│   │   PV 数据目录（provisioner 自动创建）：                 │     │
│   │   ├── kite-kite-storage-pvc-xxx/                      │     │
│   │   ├── monitoring-data-victoria-logs-0-pvc-xxx/        │     │
│   │   ├── monitoring-kube-prometheus-stack-grafana-pvc-xxx/│     │
│   │   ├── monitoring-prometheus-kube-prometheus-stack-.../ │     │
│   │   ├── mysql-data-mysql-0-pvc-xxx/                     │     │
│   │   ├── pg-pg-standalone-1-pvc-xxx/                     │     │
│   │   ├── redis-redis-standalone-redis-standalone-0-pvc-xxx/ │   │
│   │   └── redis-redis-replication-redis-replication-N-pvc-xxx/ │ │
│   └───────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────┘
```

### 核心组件

| 组件 | 说明 |
|------|------|
| **NFS 服务器** | k3s-server-1 (192.168.5.249)，Rocky Linux 9 |
| **NFS 共享目录** | `/srv/nfs/k8s`，`/24` 网段可读写，`no_root_squash` |
| **nfs-subdir-external-provisioner** | `v4.0.2`，SIG-Storage 维护的动态 provisioner |
| **StorageClass** | `nfs-storage`，`ReclaimPolicy: Delete` |
| **镜像地址** | `registry.k8s.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2`（通过 DaoCloud 镜像站 `m.daocloud.io/registry.k8s.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2` 拉取） |

### 数据流

```
PVC 创建 (storageClassName: nfs-storage)
  → Provisioner 检测到 PVC 事件
  → 在 NFS 上创建子目录: {namespace}-{pvcName}-{pvName}/
  → 创建 PV 对象绑定到 PVC
  → Pod 启动时挂载 NFS 子目录到容器内路径

Pod 重启/调度到其他节点
  → 新节点通过 NFS 挂载同一目录
  → 数据完好无损
```

---

## 3. 实施步骤

### 3.1 搭建 NFS 服务器（k3s-server-1: 192.168.5.249）

```bash
# 安装 nfs-utils
ssh root@192.168.5.249 "dnf install -y nfs-utils"

# 创建共享目录并配置 exports
ssh root@192.168.5.249 "
  mkdir -p /srv/nfs/k8s
  chmod 755 /srv/nfs/k8s
  cat > /etc/exports << 'EOF'
/srv/nfs/k8s 192.168.5.0/24(rw,sync,no_subtree_check,no_root_squash)
EOF
"

# 启动 NFS 服务
ssh root@192.168.5.249 "
  systemctl enable --now nfs-server
  exportfs -rv
  showmount -e localhost
"
```

### 3.2 所有节点安装 nfs-utils 客户端

```bash
for ip in 192.168.5.249 192.168.5.101 192.168.5.100; do
  ssh root@$ip "dnf install -y nfs-utils"
done
```

### 3.3 部署 nfs-subdir-external-provisioner

#### 拉取镜像

```bash
# 由于国内网络问题，通过 DaoCloud 镜像站拉取
for ip in 192.168.5.249 192.168.5.101 192.168.5.100; do
  ssh root@$ip "ctr -n k8s.io images pull \
    m.daocloud.io/registry.k8s.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2"
  # tag 回标准名（kubelet 通过标准名查找）
  ssh root@$ip "ctr -n k8s.io images tag \
    m.daocloud.io/registry.k8s.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2 \
    registry.k8s.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2"
done
```

#### 部署清单

所有清单在 `03-infra-k8s/nfs-provisioner/` 目录：

| 文件 | 说明 |
|------|------|
| `namespace.yaml` | nfs-provisioner 命名空间 |
| `rbac.yaml` | ServiceAccount + ClusterRole + Role |
| `deployment.yaml` | Provisioner Pod（挂载 NFS 目录） |
| `storageclass.yaml` | StorageClass: `nfs-storage` |

```bash
kubectl apply -f namespace.yaml
kubectl apply -f rbac.yaml
kubectl apply -f deployment.yaml
kubectl apply -f storageclass.yaml

# 验证
kubectl -n nfs-provisioner get pods -l app=nfs-provisioner
```

#### 验证动态供应

```bash
# 创建测试 PVC
kubectl create ns test-nfs
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
  namespace: test-nfs
spec:
  storageClassName: nfs-storage
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 100Mi
EOF

# 预期：PVC 自动 Bound
kubectl -n test-nfs get pvc test-pvc

# 验证 NFS 上自动创建了目录
ssh root@192.168.5.249 "ls /srv/nfs/k8s/"

# 清理测试
kubectl delete ns test-nfs
```

### 3.4 逐个迁移 PVC

#### 迁移策略

| 创建方式 | 迁移方法 | 涉及组件 |
|---------|---------|---------|
| **StatefulSet volumeClaimTemplates** | 删 StatefulSet → 删旧 PVC → 改 storageClassName → k8s apply | VictoriaLogs, MySQL, Prometheus |
| **独立 PVC** | 停 deploy → 删旧 PVC → 新建 PVC → 恢复 deploy | kite, Grafana |
| **Operator CR** | 删 CR → operator 自动清理 PVC → 改 storageClassName → apply CR | PostgreSQL (CNPG), Redis (redis-operator) |
| **Helm values** | 改 values-prod.yaml → helm upgrade | Grafana, Prometheus |

#### 迁移顺序

```
1. kite        (Deployment + 独立 PVC, 秒级恢复)
2. VictoriaLogs (StatefulSet + volumeClaimTemplates)
3. MySQL       (StatefulSet + volumeClaimTemplates)
4. PostgreSQL  (CNPG Operator CR)
5. Redis standalone + replication (redis-operator CR)
6. Grafana     (Helm values upgrade)
7. Prometheus  (Helm values upgrade + StatefulSet 重建)
```

详细流程见各组件各自的安装目录和 monitoring 的 install.sh。

---

## 4. 踩坑记录

### 4.1 containerd 内网镜像代理不可达

**严重程度**：🔴 致命

**现象**：

```
kubelet PullImage 失败：
  dial tcp 192.168.5.103:5003: connect: no route to host
```

**根因**：

集群配置了 `/etc/rancher/k3s/registries.yaml`，内网镜像代理 `192.168.5.103:5003`
已下线。containerd 先尝试代理，连接失败后才尝试原始 registry.k8s.io，
但外网也被屏蔽（`i/o timeout`），导致所有 `registry.k8s.io` 的镜像拉取失败。

**影响**：

- `nfs-subdir-external-provisioner` 在 Deployment 用标准镜像名时拉不下来
- Grafana pod 调度到无缓存的节点时也拉不下来

**解决方案**：

1. **修改 deployment 镜像路径**：改为 `m.daocloud.io/registry.k8s.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2`（DaoCloud 镜像站，不走 registries.yaml 的代理规则），直接在所有节点 `ctr -n k8s.io images pull` 后 tag 回标准名
2. **Grafana 固定调度节点**：通过 `nodeSelector: kubernetes.io/hostname=k3s-server-3` 固定到已有镜像的节点

**镜像拉取方式对比**：

| 方式 | 能否使用 | 说明 |
|------|---------|------|
| `registry.k8s.io/xxx` | ❌ | 本地代理 5.103 不可达，外网 registry.k8s.io 被屏蔽 |
| `m.daocloud.io/registry.k8s.io/xxx` | ✅ | DaoCloud 镜像站，不走 k3s 的 registries.yaml 规则 |
| `docker.io/xxx` | ⚠️ | 部分可拉（k3s registries.yaml 有 docker.io 的代理 5.103:5002，同样不可达）|

**长期修复建议**：修复或移除 registries.yaml 中已不可达的 mirror 配置。

### 4.2 Grafana Helm upgrade 超时

**严重程度**：🟡 高

**现象**：

```
helm upgrade --install kube-prometheus-stack ... --wait
Error: UPGRADE FAILED: context deadline exceeded
```

**根因**：

1. Helm upgrade 触发了 Grafana Pod 滚动更新
2. 新 Pod 调度到了没有镜像缓存的节点（k3s-server-2）
3. ImagePullBackOff 卡住 → `--wait` 超时

**影响**：

虽然 Helm 报错，但 PVC 已经成功创建（`kubectl apply` 是幂等的），
只是 Grafana 的滚动更新被镜像拉取卡住。

**解决方案**：

```bash
# 1. 移除 ConfigMap 中触发插件下载的 key
kubectl -n monitoring patch configmap kube-prometheus-stack-grafana \
  --type=json -p='[{"op": "remove", "path": "/data/plugins"}]'

# 2. 添加 nodeSelector 固定到有缓存的节点
kubectl -n monitoring patch deployment kube-prometheus-stack-grafana \
  --type=json -p='[{"op": "add", "path": "/spec/template/spec/nodeSelector",
    "value": {"kubernetes.io/hostname": "k3s-server-3"}}]'

# 3. 删除卡住的 Pod 重建
kubectl -n monitoring delete pod -l app.kubernetes.io/name=grafana --force
```

### 4.3 Grafana ConfigMap 的 plugins key 被环境变量引用

**严重程度**：🟡 高

**现象**：

```
Error: couldn't find key plugins in ConfigMap monitoring/kube-prometheus-stack-grafana
CreateContainerConfigError
```

**根因**：

Helm Chart 的容器模板中定义了环境变量：

```yaml
env:
  - name: GF_PLUGINS_PREINSTALL_SYNC
    valueFrom:
      configMapKeyRef:
        name: kube-prometheus-stack-grafana
        key: plugins    # ← 必须存在！删了 ConfigMap 的 plugins key 就报错
```

删除 `data.plugins` 后，容器启动时找不到这个 key，CrashLoopBackOff。

**解决方案**：

```bash
# 恢复 plugins key（空值即可）
kubectl -n monitoring patch configmap kube-prometheus-stack-grafana \
  --type=json -p='[{"op": "add", "path": "/data/plugins", "value": ""}]'
```

**教训**：ConfigMap 的 key 能否删除取决于是否有其他资源引用它，
不能仅凭「不需要了」就删掉。

### 4.4 Grafana 启动自动安装插件超时（新 PVC 空目录）

**严重程度**：🟡 高

**现象**：

Grafana 日志显示在启动时自动安装 VictoriaLogs 插件（因为 ConfigMap 中
`plugins: victoriametrics-logs-datasource` 被 env 引用），
但 grafana.com 无法访问，容器卡住或重启。

**根因**：

```yaml
# ConfigMap 中的 plugins 值
plugins: victoriametrics-logs-datasource
```

被 Helm Chart 模板映射为环境变量 `GF_PLUGINS_PREINSTALL_SYNC`，
Grafana 启动时 background installer 会尝试从 grafana.com 下载安装此插件。

**解决方案**：

ConfigMap 的 `plugins` key 保留为空值，不触发插件安装：

```yaml
data:
  plugins: ""    # 空字符串，环境变量存在但无内容
```

插件通过 `download-plugin.sh --install` 手动安装到 PVC。

### 4.5 MySQL 迁移的 PVC 二义性

**严重程度**：🟢 低

**现象**：

MySQL 同时有两个 PVC：
- `data-mysql-0`（StatefulSet volumeClaimTemplates 创建的）
- `mysql-data`（独立的 PVC YAML 创建的）

迁移后 `mysql-data` 是 nfs-storage 但未被引用，`data-mysql-0` 还是 local-path。

**根因**：

`mysql8.4/manifests/` 中既有独立 PVC（`pvc.yaml`）又有 volumeClaimTemplates
（`statefulset.yaml`）。StatefulSet 实际使用 volumeClaimTemplates 的 PVC，
独立 PVC 未被引用但留在命名空间中。

**解决方案**：

1. 修改 StatefulSet 的 storageClass → `nfs-storage`
2. 删旧 volumeClaimTemplates 的 PVC（`data-mysql-0`）
3. 重建 StatefulSet 自动创建新 PVC
4. 清理未引用的独立 PVC（`mysql-data`）

**教训**：删除 MySQL 等有状态服务后，旧 PV 数据仍占用 NFS 空间，
需要手动清理：`ssh root@249 "rm -rf /srv/nfs/k8s/archived-*/"`

---

## 5. 迁移清单

### 5.1 全部迁移的 PVC

| # | PVC | 命名空间 | 容量 | 模式 | 应用 |
|---|-----|---------|------|------|------|
| 1 | kite-storage | kite | 1Gi | 独立 PVC | Kite SQLite 数据库 |
| 2 | data-victoria-logs-0 | monitoring | 10Gi | volumeClaimTemplates | VictoriaLogs 日志 |
| 3 | kube-prometheus-stack-grafana | monitoring | 5Gi | 独立 PVC | Grafana 配置+插件 |
| 4 | prometheus-...-prometheus-0 | monitoring | 10Gi | volumeClaimTemplates | Prometheus 指标 |
| 5 | data-mysql-0 | mysql | 5Gi | volumeClaimTemplates | MySQL 数据 |
| 6 | pg-standalone-1 | pg | 5Gi | Operator CR | PostgreSQL 数据 |
| 7 | redis-standalone-redis-standalone-0 | redis | 1Gi | Operator CR | Redis 数据 |
| 8 | redis-replication-redis-replication-0 | redis | 1Gi | Operator CR | Redis 节点0 |
| 9 | redis-replication-redis-replication-1 | redis | 1Gi | Operator CR | Redis 节点1 |
| 10 | redis-replication-redis-replication-2 | redis | 1Gi | Operator CR | Redis 节点2 |

**总计**: 36Gi 存储（NFS 实际分配空间弹性扩展）

### 5.2 修改的配置文件

| 文件 | 变更内容 |
|------|---------|
| `03-infra-k8s/kite/manifests/pvc.yaml` | `storageClassName: local-path` → `nfs-storage` |
| `03-infra-k8s/monitoring/victoria-logs/statefulset.yaml` | volumeClaimTemplates storageClass 变更 |
| `03-infra-k8s/monitoring/helm/values-prod.yaml` | Grafana/Prometheus storageClassName 变更 |
| `03-infra-k8s/monitoring/helm/values-prod.yaml` | Grafana 增加 nodeSelector |
| `03-infra-k8s/mysql8.4/manifests/pvc.yaml` | storageClassName 变更 |
| `03-infra-k8s/mysql8.4/manifests/statefulset.yaml` | volumeClaimTemplates storageClass 变更 |
| `03-infra-k8s/pg17/operator/standalone/cluster.yaml` | `storageClass: local-path` → `nfs-storage` |
| `03-infra-k8s/redis/operator/standalone/redis-cr.yaml` | storageClassName 变更 |
| `03-infra-k8s/redis/operator/sentinel-ha/replication-cr.yaml` | storageClassName 变更 |

### 5.3 新增文件

| 文件 | 说明 |
|------|------|
| `03-infra-k8s/nfs-provisioner/` | 完整 provisioner 部署目录 |
| `03-infra-k8s/nfs-provisioner/namespace.yaml` | nfs-provisioner 命名空间 |
| `03-infra-k8s/nfs-provisioner/rbac.yaml` | RBAC 权限 |
| `03-infra-k8s/nfs-provisioner/deployment.yaml` | Provisioner Deployment |
| `03-infra-k8s/nfs-provisioner/storageclass.yaml` | nfs-storage StorageClass |
| `03-infra-k8s/nfs-provisioner/README.md` | 快速使用说明 |
| `03-infra-k8s/nfs-provisioner/DEPLOYMENT.md` | **本文档** |

---

## 6. 验收清单

| 检查项 | 命令 | 期望结果 |
|--------|------|---------|
| **NFS 服务器** | `ssh root@192.168.5.249 "showmount -e"` | `/srv/nfs/k8s 192.168.5.0/24` |
| **Provisioner** | `kubectl -n nfs-provisioner get pods` | `Running` |
| **StorageClass** | `kubectl get sc nfs-storage` | `nfs-storage nfs-storage Delete Immediate` |
| **PV 数量** | `kubectl get pv \| grep nfs-storage \| wc -l` | 10 |
| **NFS 目录** | `ssh root@249 "ls /srv/nfs/k8s/ \| grep -v archived \| wc -l"` | 10（不包含 archived） |
| **kite 数据** | `curl -s -o /dev/null -w "%{http_code}" http://192.168.5.249:30001/healthz` | 200 |
| **VictoriaLogs 健康** | `kubectl -n monitoring exec victoria-logs-0 -- sh -c 'wget -qO- http://127.0.0.1:9428/health'` | OK |
| **日志写入** | `kubectl -n monitoring logs -l app.kubernetes.io/name=fluent-bit --tail=3 \| grep "HTTP status=200"` | 匹配 |
| **Grafana 运行** | `kubectl -n monitoring get pods -l app.kubernetes.io/name=grafana` | `3/3 Running` |
| **插件安装** | `kubectl -n monitoring exec <grafana-pod> -- ls /var/lib/grafana/plugins/victoriametrics-logs-datasource/plugin.json` | 文件存在 |
| **数据源注册** | `kubectl -n monitoring exec <grafana-pod> -- sh -c 'wget -qO- --header="Authorization: Basic ..." http://localhost:3000/api/datasources' \| grep VictoriaLogs` | type: victoriametrics-logs-datasource |
| **所有 Pod 运行** | `kubectl get pods -A \| grep -E "monitoring\|kite\|mysql\|pg\|redis" \| grep -v "Running"` | 全部 Running |

---

## 7. 运维说明

### 7.1 日常操作

```bash
# 查看 NFS 存储使用
ssh root@192.168.5.249 "du -sh /srv/nfs/k8s/*/"

# 扩容 PVC（仅支持部分 StorageClass）
kubectl edit pvc -n <ns> <pvc-name>
# 修改 spec.resources.requests.storage
# NFS 底层不支持在线扩容，可能需要重启 Pod

# 备份整个 NFS 数据
ssh root@192.168.5.249 "tar czf /tmp/nfs-backup-\$(date +%Y%m%d).tar.gz /srv/nfs/k8s/"
```

### 7.2 注意事项

1. **NFS 服务器不能关机**：`k3s-server-1 (249)` 是 NFS 服务器，关机后所有使用 nfs-storage 的 Pod 不可用
2. **Reclaim Policy = Delete**：删除 PVC 时 NFS 上的子目录也会被删除，如果需要保留数据请先备份
3. **archived 目录**：provisioner 会自动清理的旧数据，存放在 `archived-*` 目录中
4. **Grafana nodeSelector 限制**：Grafana 固定调度到 k3s-server-3 因为该节点预缓存了镜像
5. **权限**：exports 配置了 `no_root_squash`，K8s 容器可以以 root 写入

### 7.3 灾备

| 场景 | 影响 | 恢复方式 |
|------|------|---------|
| **NFS 服务器重启** | 所有 Pod 的 NFS 挂载卡住 | 自动恢复（`hard,intr` mountOption） |
| **NFS 服务器硬盘故障** | 全部数据丢失 | 从备份恢复 |
| **PVC 误删除** | 单个服务数据丢失 | 从备份恢复对应子目录 |

### 7.4 清理归档数据

```bash
# 查看是否有 archived 目录占用空间
ssh root@192.168.5.249 "du -sh /srv/nfs/k8s/archived-* 2>/dev/null"

# 清理全部
ssh root@192.168.5.249 "rm -rf /srv/nfs/k8s/archived-* 2>/dev/null; echo done"
```

### 7.5 新增服务使用 NFS 存储

创建 PVC 时指定 `storageClassName: nfs-storage`：

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-app-data
  namespace: my-app
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: nfs-storage
  resources:
    requests:
      storage: 10Gi
```

---

## 8. FAQ

### Q: 为什么不用 Longhorn？Longhorn 不是 CNCF 项目吗？

A: 当前集群只有 3 个节点，数据量共 36Gi，用 Longhorn 大炮打蚊子。
NFS 方案简单、稳定、占用资源少。等数据量超过 100Gi 或需要快照功能时升级。

### Q: 迁移过程中数据丢了吗？

A: 是的。因为之前是 `local-path`，重启后数据已经不在，迁移是「白板重建」。
如果有需要保留的旧数据，应在迁移前 `cp` 到 NFS 目录。

### Q: 新装集群如何使用这套方案？

A: 部署流程：
1. 任选一台节点做 NFS 服务器（本文档选 249）
2. `dnf install -y nfs-utils` + `systemctl enable --now nfs-server`
3. 所有节点 `dnf install -y nfs-utils`
4. `kubectl apply -f 03-infra-k8s/nfs-provisioner/`
5. 新 PVC 指定 `storageClassName: nfs-storage`

### Q: Grafana 为什么固定在 k3s-server-3？

A: k3s-server-3 上预缓存了以下镜像（其他节点没有）：
- `docker.io/grafana/grafana:13.0.1-security-01`
- `quay.io/kiwigrid/k8s-sidecar:2.7.3`

内网镜像代理 `192.168.5.103:500x` 已不可达，且外网被屏蔽，
导致其他节点无法拉取这些镜像。修复镜像代理后可移除 nodeSelector 限制。

### Q: 如何解除 Grafana 的 nodeSelector？

A: 先确保所有节点有 Grafana 镜像，然后：
```bash
kubectl -n monitoring patch deployment kube-prometheus-stack-grafana \
  --type=json -p='[{"op": "remove", "path": "/spec/template/spec/nodeSelector"}]'
```

### Q: NFS 性能怎么样？

A: 3 台机器在内网（192.168.5.0/24），NFS v3/v4 延迟在 1ms 以内。
kite 的 SQLite、MySQL 等正常使用无压力。只有大量小文件读写（如 Prometheus 大量写入）
可能有一点性能问题，但 3 节点小集群不会达到瓶颈。

### Q: PV 误删了怎么恢复？

A: 如果 `ReclaimPolicy: Delete`，PVC 删除后 PV 和数据目录会被清理。
如果有备份，可以在 NFS 上创建同名数据目录，然后手动创建 PV + PVC。

### Q: 其他节点需要装 nfs-utils 吗？

A: 需要。NFS 协议需要客户端内核模块和 mount 工具。
但可以通过 DaemonSet 自动安装，或者在新节点加入集群时手动执行。
