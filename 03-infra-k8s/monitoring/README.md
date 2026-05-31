# kube-prometheus-stack - K8s 标准监控栈

Kubernetes 社区推荐的监控方案，包含完整的企业级监控组件。
可选部署 **VictoriaLogs + Fluent Bit** 日志采集方案。

## 组件一览

```
┌──────────────────────────────────────────────────────────────────┐
│                          Grafana                                 │
│  NodePort:30002 │ Ingress: monitor.czw-sre.internal              │
│  默认: admin / admin123                                          │
│  数据源: Prometheus(默认) + VictoriaLogs(日志)                    │
└────────┬──────────────┬──────────────────┬───────────────────────┘
         │               │                  │
    Prometheus      VictoriaLogs        告警
    (指标)          (日志存储)           │
         │               │                  │
    ┌────▼────┐   ┌─────▼──────┐   ┌──────▼─────────┐
    │Node     │   │Fluent Bit  │   │ AlertManager   │
    │Exporter │   │DaemonSet   │   │ (空路由)        │
    │Pod指标  │   │每节点采集   │   └─────────────────┘
    │kube-st. │   │K8s filter  │
    └─────────┘   │→ Victoria  │
                  └────────────┘
```

- **命名空间**：`monitoring`
- **持久化**：Grafana 5Gi + Prometheus 10Gi + VictoriaLogs 10Gi，均为 local-path PVC
- **Grafana 访问**：NodePort:30002 + Ingress `monitor.czw-sre.internal`
- **Prometheus 访问**：仅集群内部（通过 Grafana 查询）
- **告警**：AlertManager 已部署，默认空路由（仅抑制，不发送通知）

## 快速开始

```bash
# 仅部署指标监控（kube-prometheus-stack）
./install.sh

# 部署指标监控 + 日志采集（VictoriaLogs + Fluent Bit）
./install.sh --logs

# 仅部署日志采集（假设指标已部署）
./install.sh --logs-only
```

### 日志采集架构

```
┌──────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  每个 Node    │     │                  │     │                 │
│              │     │  VictoriaLogs     │     │    Grafana       │
│ Fluent Bit   │────►│  StatefulSet      │────►│  VictoriaLogs    │
│ DaemonSet    │HTTP │  10Gi PVC         │     │  数据源插件      │
│ tail + K8s   │     │  保留 30 天       │     │  /explore?      │
│ filter + buf │     │  1 副本           │     │  LogsQL 查询     │
└──────────────┘     └──────────────────┘     └─────────────────┘
```

| 组件 | 部署方式 | 副本 | 说明 |
|------|---------|------|------|
| **Fluent Bit** | DaemonSet | 每节点 1 个 | 采集所有 Pod 日志，提取 K8s 元数据 |
| **VictoriaLogs** | StatefulSet | 1 | 日志存储，原生 JSON API，10Gi PVC 保留 30 天 |

**关键设计决策：**

1. **低基数 Stream Fields** — `_stream_fields=namespace,container_name`，不包含 `pod_name`（高基数会降低查询性能）
2. **无限重试** — `Retry_Limit false`，配合 2GB 本地文件缓冲，VictoriaLogs 重启不丢日志
3. **原生 API** — 使用 `/insert/jsonline`，不走 Loki 兼容层（已知有整数 label 等兼容问题）
4. **CRI 多行处理** — 正确处理 containerd 的 P/F logtag，Java 异常栈等不会被打散
5. **K8s Filter** — 自动注入 namespace/pod/container labels 到每条日志

## 卸载

```bash
# 卸载全部
./uninstall.sh

# 仅卸载指标（保留日志组件）
./uninstall.sh --metrics

# 仅卸载日志（保留指标组件）
./uninstall.sh --logs
```

## 验收确认

```bash
# 查看 Pod 状态
kubectl get pods -n monitoring
# 期望输出（带日志时为 7-10 个 Pod）：
#   alertmanager-xxxxx                   2/2     Running
#   prometheus-kube-prometheus-stack-*   2/2     Running
#   grafana-xxxxx                        1/1     Running
#   victoria-logs-0                      1/1     Running    ← 新增
#   fluent-bit-xxxxx                     1/1     Running    ← 新增(每节点一个)
#   kube-state-metrics-xxxxx             1/1     Running
#   prometheus-node-exporter-xxxxx       1/1     Running
#   prometheus-operator-xxxxx            1/1     Running

# 查看 Service
kubectl get svc -n monitoring

# 日志数据写入确认（查看 VictoriaLogs 统计）
kubectl exec -n monitoring victoria-logs-0 -- wget -qO- http://localhost:9428/metrics | grep vl_rows_ingested_total

# 查看 Fluent Bit 状态
kubectl get daemonset -n monitoring fluent-bit
kubectl logs -n monitoring -l app.kubernetes.io/name=fluent-bit --tail=5

# 查询日志（在 Grafana Explore 中切换数据源为 VictoriaLogs）
# 示例 LogsQL 查询：
#   error and namespace:mysql
#   namespace:pg17 and container_name:postgres
#   * (查看所有日志，注意限制时间范围)
```

### 访问地址

| 服务 | 方式 | 地址 |
|------|------|------|
| Grafana | 域名 | http://monitor.czw-sre.internal（需 hosts 指向 192.168.5.240） |
| Grafana | NodePort | http://\<任一节点IP\>:30002 |
| Grafana | 默认账号 | admin / admin123 |
| VictoriaLogs | 集群内 | http://victoria-logs.monitoring:9428 |
| Fluent Bit | 集群内 | 每节点 :2020（HTTP 监控端口） |

### Grafana 预置仪表板

安装后自动部署的 K8s 仪表板（在 Grafana 中搜索）：

| 仪表板 | 说明 |
|--------|------|
| Kubernetes / Views | 集群概览 |
| Kubernetes / Nodes | 节点资源使用 |
| Kubernetes / Pods | Pod 资源使用 |
| Kubernetes / API Server | API Server 状态 |
| Node Exporter / Nodes | 节点系统指标 |
| Node Exporter / USE Method | 节点 USE 方法 |

## 日志查询快速入门（LogsQL）

VictoriaLogs 使用 **LogsQL** 查询语言，示例：

```logsql
# 查看某个命名空间的错误日志
error and namespace:mysql

# 使用过滤字段
namespace:pg17 and container_name:postgres and "ERROR"

# 排除特定内容
namespace:monitoring and not "healthcheck"

# 查看 Fluent Bit 自身的日志
container_name:fluent-bit

# 时间范围（Grafana 时间选择器控制）
# VictoriaLogs 支持 _time 字段过滤
```

## 注意

- 首次部署 CRD 安装需要 1-2 分钟，`--wait` 等待超时可手动 `kubectl get pods -n monitoring` 观察
- Grafana 默认密码 `admin123`，首次部署后请及时修改
- VictoriaLogs 插件需等待 Grafana 重启后生效（首次部署会自动重启）
- 3 节点集群总资源消耗约：CPU < 1.5 核，内存 < 3Gi（含日志组件）
- Fluent Bit DaemonSet 每个节点额外占用约 CPU 50m + 内存 100Mi
