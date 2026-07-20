# KubeBlocks 数据库集群 — 生产就绪指南

> 本文档汇总了 k8s/kubeblock/ 下所有数据库集群的生产就绪配置，
> 涵盖备份、监控、PDB 高可用、网络隔离和拓扑分布。

---

## 目录

1. [架构总览](#1-架构总览)
2. [备份策略](#2-备份策略)
3. [监控与告警](#3-监控与告警)
4. [PodDisruptionBudget](#4-poddisruptionbudget)
5. [Pod 拓扑分布](#5-pod-拓扑分布)
6. [网络隔离](#6-网络隔离)
7. [运维操作指南](#7-运维操作指南)
8. [部署清单](#8-部署清单)

---

## 1. 架构总览

### 环境信息

| 组件 | 版本 | 副本 | Namespace | 存储 |
|------|------|------|-----------|------|
| **Redis** | 7.2.4 | 2 + 3 (Sentinel) | `redis` | 5Gi (data) + 1Gi (sentinel) |
| **Valkey** | 8.1.8 | 2 + 3 (Sentinel) | `valkey` | 5Gi (data) + 1Gi (sentinel) |
| **ApeCloud MySQL** | 8.0.30 | 3 (Raft) | `mysql` | 10Gi (data) |

### 基础设施

| 组件 | 说明 | Namespace |
|------|------|-----------|
| **KubeBlocks Operator** | 1.0.2 | `operators` |
| **MinIO (S3 兼容)** | 备份存储后端 | `minio` |
| **VictoriaMetrics** | 指标采集 & 时序存储 | `monitoring` |
| **Grafana** | 仪表盘 & 可视化 | `monitoring` |
| **Cilium** | CNI + 网络策略 | `kube-system` |

### 节点分布

```
Control-plane: k3s-server-1
Agent nodes:   agent-1, agent-2  (共 2 个)
StorageClass:  nfs-client (NFS 共享存储)
```

> **节点限制说明**: 当前仅 2 个 agent 节点（`k3s-server-1` 有 `NoSchedule` 污点不可调度普通 Pod）：
>
> | 组件 | 副本 | 约束 | 说明 |
> |------|------|------|------|
> | Redis/Valkey 数据面 | 2 | 硬反亲和 | ✅ 2 节点正好各放 1 个 |
> | Redis/Valkey Sentinel | 3 | 软反亲和 | ⚠️ 必须有 2 个 Sentinel 在同一节点，节点故障时可能丢失 quorum |
> | MySQL | 3 | 软反亲和 | ⚠️ 必须有 2 个 Pod 在同一节点 |
>
> **建议**: 生产环境扩容到 3+ agent 节点，所有组件可改为硬反亲和获得最高容错。

---

## 2. 备份策略

### 2.1 备份仓库

Writes to `common/backuprepo/`:

| 文件 | 说明 |
|------|------|
| `backuprepo.yaml` | MinIO S3 BackupRepo 定义（Tool 模式） |
| `credential-secret.yaml` | MinIO 访问凭证 Secret |

```bash
# 一次性部署
kubectl apply -f kubeblock/common/backuprepo/credential-secret.yaml
kubectl apply -f kubeblock/common/backuprepo/backuprepo.yaml
```

### 2.2 备份调度

KubeBlocks 在创建 Cluster 时**自动创建** BackupPolicy 和 BackupSchedule，
但默认所有调度是 **disabled** 状态。生产环境需要手动启用。

```bash
# 已通过 kubectl patch 启用，执行如下：
kubectl patch backupschedule redis-redis-backup-schedule -n redis --type='json' -p='[
  {"op":"replace","path":"/spec/schedules/0/enabled","value":true},
  {"op":"replace","path":"/spec/schedules/0/cronExpression","value":"0 3 * * *"},
  {"op":"replace","path":"/spec/schedules/1/enabled","value":true},
  {"op":"replace","path":"/spec/schedules/1/cronExpression","value":"0 */6 * * *"}
]'
```

各实例的启用参考文件：

- `redis/test-default/backup-enable.yaml`
- `valkey/test-default/backup-enable.yaml`
- `apecloud-mysql/test-default/backup-enable.yaml`

### 2.3 调度计划

| 数据库 | 全量备份 | 增量备份 | 保留策略 |
|--------|---------|---------|---------|
| Redis | 每日 03:00 (datafile) | 每 6 小时 (AOF) | 全量 7d, 增量 2d |
| Valkey | 每日 03:10 (datafile) | 每 6 小时 (AOF) | 全量 7d, 增量 2d |
| MySQL | 每日 03:20 (xtrabackup) | — | 全量 7d |

> 三个实例的备份时间故意错开（3:00 / 3:10 / 3:20），避免同时触发释放 I/O 峰值。

### 2.4 手动备份

```bash
# Redis 手动全量备份
kubectl apply -f - <<EOF
apiVersion: dataprotection.kubeblocks.io/v1alpha1
kind: Backup
metadata:
  name: redis-manual-backup-$(date +%Y%m%d-%H%M)
  namespace: redis
spec:
  backupMethod: datafile
  backupPolicyName: redis-redis-backup-policy
  deletionPolicy: Delete
EOF

# MySQL 手动全量备份
kubectl apply -f - <<EOF
apiVersion: dataprotection.kubeblocks.io/v1alpha1
kind: Backup
metadata:
  name: mysql-manual-backup-$(date +%Y%m%d-%H%M)
  namespace: mysql
spec:
  backupMethod: xtrabackup
  backupPolicyName: apecloud-mysql-mysql-backup-policy
  deletionPolicy: Delete
EOF
```

### 2.5 恢复操作

参考各实例目录下的 `restore.yaml`：

```bash
# 从备份恢复 Redis
kubectl apply -f redis/test-default/restore.yaml

# 从备份恢复 MySQL
kubectl apply -f apecloud-mysql/test-default/restore.yaml
```

> **注意**: 恢复前需确认目标集群状态。如果恢复为同集群，需要先停止当前集群。
> 参考: `kubectl cluster -n <ns> stop <cluster-name>`

### 2.6 查看备份状态

```bash
kubectl get backup -A
kubectl describe backup -n <namespace> <backup-name>

# 查看 MinIO 中备份文件
kubectl exec -n minio deploy/minio-pool-0 -- mc ls myminio/kubeblocks-backup
```

---

## 3. 监控与告警

### 3.1 指标采集

VictoriaMetrics vmagent 已配置 `selectAllByDefault: true`，
自动发现所有 VMPodScrape 资源。

采集配置：

| 数据库 | Exporter 端口 | Metrics Path | VMPodScrape |
|--------|-------------|--------------|-------------|
| Redis | 9121 (http-metrics) | `/metrics` | `redis-pod-scrape` / `redis-sentinel-pod-scrape` |
| Valkey | 9121 (http-metrics) | `/metrics` | `valkey-pod-scrape` / `valkey-sentinel-pod-scrape` |
| MySQL | 9104 (http-metrics) | `/metrics` | `mysql-pod-scrape` |

验证采集：

```bash
# 查看 vmagent 发现的目标
kubectl port-forward -n monitoring svc/vmagent-monitoring 8429:8429
# 然后访问 http://localhost:8429/targets

# 或者直接查询 VictoriaMetrics
kubectl port-forward -n monitoring svc/vmsingle-monitoring 8428:8428
# curl http://localhost:8428/api/v1/query?query=redis_up
```

### 3.2 Grafana 仪表盘

| 仪表盘 | 数据源 | 对应 ConfigMap |
|--------|--------|---------------|
| Redis 监控 (ID 11835) | VictoriaMetrics | `redis-dashboard` |
| MySQL Overview (ID 7362) | VictoriaMetrics | `mysql-dashboard` |

仪表盘通过 Grafana sidecar (`grafana-sc-dashboard`) 自动加载：
```bash
kubectl apply -f kubeblock/common/grafana/redis-dashboard.yaml
kubectl apply -f kubeblock/common/grafana/mysql-dashboard.yaml
```

访问 Grafana：
```bash
kubectl port-forward -n monitoring svc/vm-grafana 8080:80
# 浏览器打开 http://localhost:8080
# 默认凭据见 Helm values（通常是 admin / prom-operator）
```

### 3.3 告警规则

| 规则文件 | Namespace | 严重级别 | 覆盖内容 |
|---------|-----------|---------|---------|
| `redis-vmrule-alerts.yaml` | redis | Critical / Warning | 实例宕机、内存高、CPU 高、复制中断、键驱逐 |
| `valkey-vmrule-alerts.yaml` | valkey | Critical / Warning | 同上（Valkey 兼容 Redis 指标格式） |
| `mysql-vmrule-alerts.yaml` | mysql | Critical / Warning | 实例宕机、Raft quorum 丢失、复制延迟、慢查询 |

关键告警：

| 告警名称 | 条件 | 严重级别 | 预期响应 |
|---------|------|---------|---------|
| RedisDown | `redis_up == 0` for 1m | Critical | 立即排查 Pod 状态和日志 |
| RedisMissingMaster | master count < 1 | Critical | 检查 Sentinel 选主日志 |
| RedisMemoryHigh | memory > 85% for 5m | Warning | 评估是否需要扩容或调整 maxmemory-policy |
| MySQLRaftQuorumLost | cluster_size < 2 | Critical | 排查节点故障，恢复共识 |
| MySQLSlowQueries | slow_queries 增加 | Warning | 检查慢查询 SQL，优化索引 |

---

## 4. PodDisruptionBudget

| PDB | Namespace | minAvailable | 作用 |
|-----|-----------|-------------|------|
| `redis-pdb` | redis | 1 | Redis 数据面：至少 1 个副本可用 |
| `redis-sentinel-pdb` | redis | 2 | Sentinel：至少 2 个存活维持 quorum |
| `valkey-pdb` | valkey | 1 | Valkey 数据面 |
| `valkey-sentinel-pdb` | valkey | 2 | Valkey Sentinel |
| `mysql-pdb` | mysql | 2 | MySQL Raft：至少 2 个存活维持共识 |

> 节点维护时必须使用 `kubectl drain`（遵循 PDB），
> 不要直接 `kubectl delete pod` 驱逐（绕过 PDB 会导致服务中断风险）。

```bash
# 正确做法：节点维护
kubectl drain agent-1 --ignore-daemonsets --delete-emptydir-data
# ...维护完成后...
kubectl uncordon agent-1
```

---

## 5. Pod 拓扑分布

### 5.1 配置策略

所有 Cluster 的 componentSpecs 均已配置 `schedulingPolicy.affinity.podAntiAffinity`：

- **Redis / Valkey 数据面**: `required` 硬反亲和 + `preferred` 软反亲和大权重
  — 2 副本分布在 2 个不同节点
- **Redis / Valkey Sentinel**: `required` 硬反亲和 — 3 Sentinel 分布在 3 个不同节点
  （control-plane 也可以调度）
- **ApeCloud MySQL**: `preferred` 软反亲和（仅权重 100）
  — 当前 2 节点无法满足 3 副本硬反亲和，用软约束最大化分散

### 5.2 查看 Pod 分布

```bash
kubectl get pods -n redis -o wide
kubectl get pods -n valkey -o wide
kubectl get pods -n mysql -o wide
```

确认每个 Pod 运行在不同的节点上。如果有 Pod 处于 Pending 状态，
通常是因为硬反亲和无法满足（节点不足）。

---

## 6. 网络隔离

### 6.1 CiliumNetworkPolicy

每个数据库 namespace 已配置入站和出站策略：

**入站（Ingress）**：

| 来源 | Redis | Valkey | MySQL |
|------|-------|--------|-------|
| 同 namespace | ✅ 6379, 26379 | ✅ 6379, 26379 | ✅ 3306 |
| monitoring | ✅ 9121 (metrics) | ✅ 9121 (metrics) | ✅ 9104 (metrics) |
| kdebug | ✅ 6379, 26379 | ✅ 6379, 26379 | ✅ 3306 |

**出站（Egress）**：

所有实例仅允许：
- DNS 解析（kube-system/kube-dns:53）
- 集群内任意 TCP 通信（主从复制、MinIO S3 备份上传）

### 6.2 自定义访问

如果需要从其他 namespace 访问数据库，修改对应的网络策略文件：

```bash
# 以 redis 为例，添加新的允许来源
kubectl edit cnp redis-network-isolation -n redis
```

在 `ingress` 数组中添加条目：

```yaml
- fromEndpoints:
    - matchLabels:
        io.kubernetes.pod.namespace: <your-namespace>
  toPorts:
    - ports:
        - port: "6379"
          protocol: TCP
```

### 6.3 临时禁用策略

```bash
kubectl delete cnp --all -n <namespace>
# 排查完问题后重新 apply
kubectl apply -f kubeblock/common/network-policy/<file>.yaml
```

---

## 7. 运维操作指南

### 7.1 日常巡检

```bash
# 1. 检查集群状态
kubectl get cluster -A

# 2. 检查 Pod 分布
kubectl get pods -A -o wide | grep -E 'redis|valkey|mysql'

# 3. 检查 PDB 状态
kubectl get pdb -A

# 4. 检查备份状态
kubectl get backup -A
kubectl get backupschedule -A

# 5. 检查备份仓库
kubectl get backuprepo

# 6. 检查备份存储空间
kubectl exec -n minio deploy/minio-pool-0 -- du -sh /data/kubeblocks-backup 2>/dev/null

# 7. 检查监控采集
kubectl get vmpodscrape -A
```

### 7.2 手动触发备份

```bash
# Redis AOF 增量备份
kubectl create -n redis -f - <<EOF
apiVersion: dataprotection.kubeblocks.io/v1alpha1
kind: Backup
metadata:
  name: redis-aof-$(date +%Y%m%d-%H%M%S)
spec:
  backupMethod: aof
  backupPolicyName: redis-redis-backup-policy
  deletionPolicy: Delete
EOF
```

### 7.3 节点维护流程

```bash
# 1. 检查各 PDB 的 ALLOWED DISRUPTIONS（应该 >= 1）
kubectl get pdb -A

# 2. 开始排空节点（PDB 会保护不被过度驱逐）
kubectl drain agent-1 --ignore-daemonsets --delete-emptydir-data

# 3. 执行维护...

# 4. 恢复节点
kubectl uncordon agent-1

# 5. 确认 Pod 重新调度回节点
kubectl get pods -n redis -o wide
```

### 7.4 实例扩缩容

```bash
# Redis 从 2 副本扩展到 3 副本
kubectl patch cluster redis -n redis --type='merge' -p='{
  "spec": {"componentSpecs": [{"name": "redis", "replicas": 3}]}
}'

# 注意：扩缩容后需要检查 PDB 是否需要调整
```

### 7.5 升级流程

```bash
# 1. 先确认当前版本
kubectl get cluster -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.componentSpecs[0].serviceVersion}{"\n"}{end}'

# 2. 升级版本（以 Valkey 为例）
kubectl edit cluster valkey -n valkey
# 修改 spec.componentSpecs[0].serviceVersion

# 3. 监控升级进度
kubectl get pods -n valkey -w
```

### 7.6 集群故障恢复

```bash
# 如果集群进入 Failed 状态
kubectl describe cluster <name> -n <ns>

# 常见原因：
# - 硬反亲和导致 Pod 调度失败 → 改为 preferred
# - PVC 空间不足 → 扩容 PVC
# - 节点资源不足 → 检查资源分配

# 如果无法修复，可删除重建（包含 PDB、网络策略需重新 apply）
kubectl delete cluster <name> -n <ns>
# 重新 apply cluster.yaml
```

---

## 8. 部署清单

### 初始部署顺序

```bash
# 1. 创建 MinIO 备份仓库
kubectl apply -f kubeblock/common/backuprepo/credential-secret.yaml
kubectl apply -f kubeblock/common/backuprepo/backuprepo.yaml

# 2. 部署/更新集群
kubectl apply -f kubeblock/redis/test-default/cluster.yaml
kubectl apply -f kubeblock/valkey/test-default/cluster.yaml
kubectl apply -f kubeblock/apecloud-mysql/test-default/cluster.yaml

# 3. 等待集群就绪
kubectl get cluster -A -w

# 4. 部署 PDB
kubectl apply -f kubeblock/common/pdb/

# 5. 部署网络策略
kubectl apply -f kubeblock/common/network-policy/

# 6. 部署监控
kubectl apply -f kubeblock/common/grafana/
# 然后每个实例的监控配置
kubectl apply -f kubeblock/redis/test-default/vmpodscrape.yaml
kubectl apply -f kubeblock/redis/test-default/vmrule-alerts.yaml
kubectl apply -f kubeblock/valkey/test-default/vmpodscrape.yaml
kubectl apply -f kubeblock/valkey/test-default/vmrule-alerts.yaml
kubectl apply -f kubeblock/apecloud-mysql/test-default/vmpodscrape.yaml
kubectl apply -f kubeblock/apecloud-mysql/test-default/vmrule-alerts.yaml

# 7. 启用备份调度
# 已通过 kubectl patch 启用，新部署可 apply backup-enable.yaml
kubectl apply -f kubeblock/redis/test-default/backup-enable.yaml
kubectl apply -f kubeblock/valkey/test-default/backup-enable.yaml
kubectl apply -f kubeblock/apecloud-mysql/test-default/backup-enable.yaml

# 8. 验证
kubectl get backuprepo,cluster,pdb,cnp,vmpodscrape,vmrule -A
kubectl get configmap -n monitoring -l grafana_dashboard=1
```

### 文件结构总览

```
kubeblock/
├── docs/
│   └── production-ready.md              ← 本文档
├── common/
│   ├── backuprepo/
│   │   ├── credential-secret.yaml       # MinIO 访问凭证
│   │   └── backuprepo.yaml              # BackupRepo CR
│   ├── pdb/
│   │   ├── redis-pdb.yaml
│   │   ├── valkey-pdb.yaml
│   │   └── mysql-pdb.yaml
│   ├── network-policy/
│   │   ├── redis-network-policy.yaml
│   │   ├── valkey-network-policy.yaml
│   │   └── mysql-network-policy.yaml
│   └── grafana/
│       ├── redis-dashboard.yaml
│       └── mysql-dashboard.yaml
├── redis/test-default/
│   ├── cluster.yaml                     # + schedulingPolicy
│   ├── vmpodscrape.yaml                 # 新增
│   ├── vmrule-alerts.yaml               # 新增
│   ├── restore.yaml                     # 新增（参考）
│   └── backup-enable.yaml               # 新增（参考）
├── valkey/test-default/
│   ├── cluster.yaml                     # + schedulingPolicy
│   ├── vmpodscrape.yaml                 # 新增
│   ├── vmrule-alerts.yaml               # 新增
│   ├── restore.yaml                     # 新增（参考）
│   └── backup-enable.yaml               # 新增（参考）
└── apecloud-mysql/test-default/
    ├── cluster.yaml                     # + schedulingPolicy
    ├── vmpodscrape.yaml                 # 新增
    ├── vmrule-alerts.yaml               # 新增
    ├── restore.yaml                     # 新增（参考）
    └── backup-enable.yaml               # 新增（参考）
```

---

## 变更记录

| 日期 | 变更内容 | 操作者 |
|------|---------|--------|
| 2026-07-20 | 初始创建：备份、监控、PDB、网络策略、拓扑分布 | jory |
