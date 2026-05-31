# 部署实战记录：VictoriaLogs + Fluent Bit 日志采集

> 本文档记录整个日志采集方案的搭建过程、踩坑记录和修复方案。
> 确保再次部署时完全幂等，不会踩重复的坑。

---

## 目录

- [1. 架构总览](#1-架构总览)
- [2. 部署步骤](#2-部署步骤)
- [3. 幂等性说明](#3-幂等性说明)
- [4. 踩坑记录](#4-踩坑记录)
  - [4.1 VictoriaLogs v1.49.0 移除了 Loki 兼容查询 API](#41-victorialogs-v1490-移除了-loki-兼容查询-api)
  - [4.2 Grafana initChownData local-path PVC 权限拒绝](#42-grafana-etchowndata-local-path-pvc-权限拒绝)
  - [4.3 VictoriaLogs 插件国内网络无法下载](#43-victorialogs-插件国内网络无法下载)
  - [4.4 VictoriaLogs 镜像拉取失败（docker.io 网络问题）](#44-victorialogs-镜像拉取失败dockerio-网络问题)
  - [4.5 Fluent Bit 配置缺陷：Retry_Limit 3 导致丢日志](#45-fluent-bit-配置缺陷retry_limit-3-导致丢日志)
- [5. 验收清单](#5-验收清单)
- [6. FAQ](#6-faq)

---

## 1. 架构总览

```
┌─────────────────────────────────────────────────────────────┐
│                      Grafana                                │
│  NodePort:30002 │ admin/admin123                             │
│  数据源: Prometheus(指标) + VictoriaLogs(日志)               │
│  插件: victoriametrics-logs-datasource v0.27.1              │
└────────┬──────────────┬─────────────────────────────────────┘
         │              │
    ┌────▼────┐   ┌─────▼──────────┐
    │Prometheus│   │ VictoriaLogs   │
    │指标存储   │   │ 日志存储        │
    │保留 7d   │   │ 保留 30d       │
    │10Gi PVC  │   │ 10Gi PVC       │
    └──────────┘   └──────┬─────────┘
                          │ HTTP (/insert/jsonline)
                     ┌────▼──────────┐
                     │ Fluent Bit     │
                     │ DaemonSet      │
                     │ 每节点 1 个    │
                     │ tail + K8s     │
                     │ filter + buf   │
                     │ Retry: false   │
                     │ 缓冲: 2G       │
                     └──────┬─────────┘
                            │ tail
                     ┌──────▼──────────┐
                     │  /var/log/pods/  │
                     │  所有容器 stdout │
                     └─────────────────┘
```

### 数据流

```
Pod 标准输出 → kubelet → /var/log/pods/*/*/*.log
  → Fluent Bit tail input (CRI 解析器)
  → K8s filter (注入 namespace/pod/container_name 等标签)
  → modify filter (加 cluster_name, node_name, environment)
  → grep filter (排除空行)
  → HTTP output (gzip 压缩 → VictoriaLogs /insert/jsonline)
  → VictoriaLogs 写入存储 (10Gi PVC, 保留 30 天)
  → Grafana 查询 (VictoriaLogs 数据源, LogsQL)
```

### 关键设计决策

| 决策点 | 选择 | 原因 |
|--------|------|------|
| 采集器 | **Fluent Bit** | CNCF 毕业，~2MB 二进制，~20MB/节点内存 |
| 存储 | **VictoriaLogs** | 单二进制，内存为 Loki 1/5，原生 LogsQL |
| 传输协议 | **原生 JSON API** (`/insert/jsonline`) | 不走 Loki 兼容层（v1.49.0 已移除）+ 功能完整 |
| 查询 | **官方 Grafana 插件** | 支持完整 LogsQL 语法 |
| 流划分 | `_stream_fields=namespace,container_name` | 低基数，不包含 pod_name |
| 缓冲 | 2GB 文件系统缓冲 | 后端重启时日志不丢 |
| 重试 | `Retry_Limit false`（无限重试） | 配合缓冲，保证零丢失 |
| 多行 | CRI 解析器 | 正确合并 Java 异常栈等跨行日志 |

---

## 2. 部署步骤

### 2.1 前置条件

```bash
# k3s 集群正常运行
kubectl cluster-info

# kube-prometheus-stack 离线 Chart 存在
ls helm/remote-kube-prometheus-stack-85.1.3/Chart.yaml
```

### 2.2 部署指标监控（如果未安装）

```bash
cd 03-infra-k8s/monitoring
./install.sh
```

### 2.3 部署日志采集

```bash
# 方式一：独立部署日志（如果指标已存在）— 推荐
./install.sh --logs-only

# 方式二：指标 + 日志一起部署
./install.sh --logs

# 方式三：部署日志但跳过插件安装（后续再手动装）
./install.sh --logs-only --skip-plugin
```

### 2.4 手动安装 Grafana 插件（如果跳过或失败时）

```bash
cd 03-infra-k8s/monitoring
./plugins/download-plugin.sh --install
```

### 2.5 验收

```bash
# 确认所有 Pod 运行
kubectl get pods -n monitoring
# 期望输出（带日志时 8-10 个 Pod）：
#   victoria-logs-0                      1/1     Running
#   fluent-bit-xxxxx                     1/1     Running  (每节点 1 个)
#   kube-prometheus-stack-grafana-xxxxx  3/3     Running

# 检查日志写入
kubectl exec -n monitoring victoria-logs-0 -- \
  sh -c 'wget -q -O- http://127.0.0.1:9428/metrics | grep "^vl_bytes_ingested_total"'

# Fluent Bit 连通性检查
kubectl logs -n monitoring -l app.kubernetes.io/name=fluent-bit --tail=3 | grep "HTTP status=200"

# VictoriaLogs 健康检查
kubectl exec -n monitoring victoria-logs-0 -- \
  sh -c 'wget -q -O- http://127.0.0.1:9428/health'

# Grafana 插件检查
kubectl exec -n monitoring -l app.kubernetes.io/name=grafana -- \
  sh -c 'ls /var/lib/grafana/plugins/victoriametrics-logs-datasource/plugin.json'

# Grafana API 验证数据源
kubectl exec -n monitoring -l app.kubernetes.io/name=grafana -- \
  sh -c 'wget -q -O- --header="Authorization: Basic $(echo -n admin:admin123 | base64)" \
  http://localhost:3000/api/datasources/name/VictoriaLogs'
```

---

## 3. 幂等性说明

再次执行 `./install.sh --logs-only` 是**完全安全的**：

| 组件 | 操作 | 幂等行为 |
|------|------|---------|
| **VictoriaLogs** | `kubectl apply` | YAML 无变更时不做任何操作；镜像变更时 StatefulSet 自动滚动更新 |
| **Fluent Bit** | `kubectl apply` | YAML 无变更时不做任何操作；DaemonSet 滚动更新 |
| **Grafana** | `helm upgrade --install` | Helm 自动 diff，只有变更部分会更新 |
| **数据源 ConfigMap** | `kubectl apply` | 无变更时 no-op |
| **插件** | `./plugins/download-plugin.sh --install` | 检查 PVC 上 plugin.json 是否存在，已存在则跳过 |

### 重复执行建议

```bash
# 日常巡检/幂等部署
./install.sh --logs-only

# 修改配置后重跑
# 改 values-prod.yaml → 重新 helm upgrade
# 改 fluent-bit configmap → 重新 kubectl apply → Fluent Bit 自动 reload
# 改 victoria-logs statefulset → 重新 kubectl apply → 自动滚动更新
```

---

## 4. 踩坑记录

### 4.1 VictoriaLogs v1.49.0 移除了 Loki 兼容查询 API

**严重程度**：🔴 致命

**现象**：

```
Grafana Loki 数据源查询时返回：
"unsupported path requested: "/loki/api/v1/query_range""
```

**根因**：

VictoriaLogs **v1.49.0+ 彻底移除了 `/loki/api/v1/*` 路径**（之前只是标记为 deprecated），
所有查询必须走原生 LogsQL API（`/select/logsql/query`），
且之前版本的 `/select/0/victoria/logs/api/v1/query_range` 也已移除。

这使得 Grafana 内置的 Loki 数据源完全无法连接到 VictoriaLogs。

**修复**：

安装官方 `victoriametrics-logs-datasource` Grafana 插件，数据源类型改为 `victoriametrics-logs-datasource`。

```yaml
# values-prod.yaml
grafana:
  grafana.ini:
    plugins:
      allow_loading_unsigned_plugins: victoriametrics-logs-datasource
```

**版本影响**：

| VictoriaLogs 版本 | Loki 兼容 API | 推荐做法 |
|------------------|--------------|---------|
| < v1.44.0 | 支持 | 可用 Loki 数据源，但功能有限 |
| v1.44.0 - v1.46.0 | Deprecated | 建议迁移到官方插件 |
| **>= v1.49.0** | **已移除** | **必须用官方插件** |

---

### 4.2 Grafana initChownData local-path PVC 权限拒绝

**严重程度**：🔴 致命

**现象**：

```
Grafana pod stuck in Init:CrashLoopBackOff
Init container "init-chown-data" 日志：
chown: /var/lib/grafana/png: Permission denied
chown: /var/lib/grafana/csv: Permission denied
chown: /var/lib/grafana/pdf: Permission denied
```

**根因**：

Grafana Helm chart 默认开启 `initChownData`，init 容器用 busybox 执行 `chown -R 472:472 /var/lib/grafana`。
但 local-path 存储类创建的 PVC 默认由 root 拥有，init 容器以 grafana 用户（uid 472）运行时，
无法 chown root 拥有的 `/var/lib/grafana/png`、`/var/lib/grafana/csv` 等**子目录**。

注意：`/var/lib/grafana/` 根目录本身能被 chown（因为 PVC 挂载时已设置权限），
但子目录是 Grafana 容器进程在启动时创建的，归 root 所有。

**修复**：

```yaml
# values-prod.yaml
grafana:
  initChownData:
    enabled: false
  grafana.ini:
    plugins:
      allow_loading_unsigned_plugins: victoriametrics-logs-datasource
```

如果 PVC 已存在且缺少这些目录，需先手动创建：

```bash
kubectl exec -n monitoring <grafana-pod> -- sh -c '
  mkdir -p /var/lib/grafana/png /var/lib/grafana/csv /var/lib/grafana/pdf
  chmod 755 /var/lib/grafana/png /var/lib/grafana/csv /var/lib/grafana/pdf
'
```

**注意**：禁用 `initChownData` 后，如果更换了 Grafana 镜像导致 uid 变化，需要手动处理权限。
但 kube-prometheus-stack 固定的 Grafana 版本（13.0.1）uid 是稳定的。

---

### 4.3 VictoriaLogs 插件国内网络无法下载

**严重程度**：🟡 高（仅影响首次部署）

**现象**：

```yaml
# Helm values-prod.yaml 中的 plugins 配置
grafana:
  plugins:
    - victoriametrics-logs-datasource
```

Helm 安装时 init 容器执行 `grafana-cli plugins install` 会尝试从 grafana.com 下载，
但国内网络无法访问，init 容器一直失败。

**根因**：

`grafana-cli plugins install` 从 `https://grafana.com/api/plugins/` 下载插件包，
该域名被国内网络屏蔽。从 GitHub Releases 的直链下载也被屏蔽。

**修复**：

使用 `gh-proxy.com` 反向代理下载：

```bash
# 通过 gh-proxy 下载（已在 download-plugin.sh 中封装）
curl -sL -o plugin.tar.gz \
  "https://gh-proxy.com/https://github.com/VictoriaMetrics/victorialogs-datasource/releases/download/v0.27.1/victoriametrics-logs-datasource-v0.27.1.tar.gz"

# 解压并复制到 Grafana PVC
tar xzf plugin.tar.gz
kubectl cp victoriametrics-logs-datasource monitoring/<grafana-pod>:/var/lib/grafana/plugins/

# 重启 Grafana
kubectl rollout restart -n monitoring deployment/kube-prometheus-stack-grafana
```

注意事项：

- 插件是**未签名**的，必须配置 `allow_loading_unsigned_plugins`
- 复制到 PVC 后，重启 Grafana 即可加载，pod 重建后不会丢失
- 不建议在 values-prod.yaml 中启用 `plugins:`（会触发网络下载），已注释掉

---

### 4.4 VictoriaLogs 镜像拉取失败（docker.io 网络问题）

**严重程度**：🟡 高

**现象**：

```
Failed to pull image "victoriametrics/victoria-logs:v1.46.0-victorialogs":
dial tcp 103.252.115.49:443: i/o timeout
```

**根因**：

docker.io registry-1.docker.io 被国内网络屏蔽。
原有的 Fluent Bit 镜像能拉下来是因为 docker.io 部分镜像通过 CDN 或其他镜像加速可达。

**修复**：

1. 尝试不同的 tag 版本，`v1.49.0` 拉取成功（可能是 CDN 缓存命中）
2. 注意 `v1.46.0-victorialogs` 与 `v1.49.0` 的 tag 命名不一致：
   - 旧版：`v1.46.0-victorialogs`（带 -victorialogs 后缀）
   - 新版：`v1.49.0`（裸版本号）
3. 如果有私有镜像仓库，提前 pull 并重新 tag 是最可靠的方案

**建议**：

```bash
# 如果可以访问外网的机器，pull 后推送到私有仓库
docker pull victoriametrics/victoria-logs:v1.49.0
docker tag victoriametrics/victoria-logs:v1.49.0 114.115.130.46/jlkj-base/victoriametrics/victoria-logs:v1.49.0
docker push 114.115.130.46/jlkj-base/victoriametrics/victoria-logs:v1.49.0
```

---

### 4.5 Fluent Bit 配置缺陷：Retry_Limit 3 导致丢日志

**严重程度**：🟡 高（Docker 版）

**现象**：

当 VictoriaLogs 重启时，Fluent Bit HTTP output 重试 3 次后抛弃 chunk，
且 Fluent Bit 进程存活但不再发送这部分日志。

**根因**：

Docker 版 Fluent Bit 配置中 `Retry_Limit 3` 限制最多重试 3 次，
超过后标记 chunk 为不可重试并删除，导致**永久丢日志**。

这是 GitHub issue [#8709](https://github.com/fluent/fluent-bit/issues/8709) 中报告的问题。
虽然该 issue 说的是 Fluent Bit 在 VictoriaLogs 重启后连不上的问题，
但 `Retry_Limit false` + 大文件缓冲 = 标准缓解方案。

**修复**：

```ini
# fluent-bit.conf SERVICE 段
[SERVICE]
    storage.total_limit_size  2G      # 本地缓冲上限 2GB

# OUTPUT 段
[OUTPUT]
    Retry_Limit       false           # 无限重试，配合 2G 缓冲
```

K8s 版 Fluent Bit 直接从配置中就修复了这两个参数，不需要修改。

---

## 5. 验收清单

| 检查项 | 命令 | 期望结果 |
|--------|------|---------|
| **VictoriaLogs Pod** | `kubectl get pods -n monitoring -l app.kubernetes.io/name=victoria-logs` | 1/1 Running |
| **Fluent Bit Pod** | `kubectl get pods -n monitoring -l app.kubernetes.io/name=fluent-bit` | 每个节点 1/1 Running |
| **Grafana Pod** | `kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana` | 3/3 Running |
| **VictoriaLogs 健康** | `kubectl exec -n monitoring victoria-logs-0 -- wget -qO- http://127.0.0.1:9428/health` | OK |
| **数据写入** | `kubectl exec -n monitoring victoria-logs-0 -- sh -c 'wget -qO- http://127.0.0.1:9428/metrics \| grep vl_bytes_ingested_total'` | > 0 |
| **Fluent Bit 连通** | `kubectl logs -n monitoring -l app.kubernetes.io/name=fluent-bit --tail=3 \| grep "HTTP status=200"` | 有匹配行 |
| **插件安装** | `kubectl exec -n monitoring -l app.kubernetes.io/name=grafana -- sh -c 'ls /var/lib/grafana/plugins/victoriametrics-logs-datasource/plugin.json'` | 文件存在 |
| **数据源注册** | `kubectl get configmap -n monitoring -l grafana_datasource=1` | victoria-logs-datasource |
| **PVC 状态** | `kubectl get pvc -n monitoring \| grep victoria` | Bound, 10Gi |
| **Grafana 登录** | 浏览器访问 `http://<节点IP>:30002` | 登录页，admin/admin123 |
| **Explore 查询** | Grafana → Explore → 切换 VictoriaLogs → 输入 `*` | 返回日志列表 |

---

## 6. FAQ

### Q: 再次运行 ./install.sh --logs-only 会破坏现有配置吗？

A: **不会**。`kubectl apply` 和 `helm upgrade --install` 都是幂等的。插件安装脚本会检查 PVC 上是否已存在。

### Q: VictoriaLogs 升级怎么弄？

A: 修改 `victoria-logs/statefulset.yaml` 中的 `image` tag，然后重新 `kubectl apply`。
StatefulSet 会自动进行滚动更新。PVC 数据不受影响。

### Q: Fluent Bit 要加新的日志 filter？

A: 修改 `fluent-bit/configmap.yaml`，重新 `kubectl apply`。
Fluent Bit 会自动热加载（检测到 configmap 变化会 reload）。

### Q: Grafana 密码忘了怎么办？

A:
```bash
kubectl get secret -n monitoring -l app.kubernetes.io/component=admin-secret \
  -o jsonpath='{.items[0].data.admin-password}' | base64 -d
```

### Q: 磁盘空间不够了怎么办？

VictoriaLogs 保留 30 天，但如果日志量大可以：
- 缩短保留期：修改 statefulset.yaml 中 `--retentionPeriod` 参数
- 缩小 PVC：需要重新创建 StatefulSet（会导致数据丢失）
- 加存储类：改用更大的 PV 或 NFS

### Q: Grafana 插件在 pod 重建后消失吗？

A: **不会**。插件存储在 PVC 上（`/var/lib/grafana/plugins/`），
PVC 是持久化的，pod 删除重建后插件依然存在。

---

## 变更记录

| 日期 | 版本 | 变更内容 |
|------|------|---------|
| 2026-05-31 | v1.0 | 初始部署，记录所有踩坑和修复 |
