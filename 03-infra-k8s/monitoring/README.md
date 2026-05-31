# kube-prometheus-stack - K8s 标准监控栈

Kubernetes 社区推荐的监控方案，包含完整的企业级监控组件。
可选部署 **VictoriaLogs + Fluent Bit** 日志采集方案。

## 组件一览

```
┌──────────────────────────────────────────────────────────────────┐
│                          Grafana                                 │
│  NodePort:30002 │ Ingress: monitor.czw-sre.internal              │
│  默认: admin / admin123                                          │
│  数据源: Prometheus(默认) + VictoriaLogs(日志插件)                │
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

## 日志采集架构

```
每个 Node → Fluent Bit (DaemonSet) → HTTP → VictoriaLogs (StatefulSet) → Grafana (插件)
  tail     │ K8s filter │ 2G buffer │  原生 JSON API  │ 10Gi PVC 30天    │  LogsQL
```

### 关键设计

| 决策 | 选择 | 说明 |
|------|------|------|
| 采集器 | **Fluent Bit** | CNCF 毕业，~20MB/节点 |
| 存储 | **VictoriaLogs v1.49.0** | 内存为 Loki 1/5，LogsQL 表达力强 |
| 传输协议 | `/insert/jsonline`（原生API） | 不走 Loki 兼容层 |
| 流划分 | `namespace,container_name` | 低基数，不含 pod_name |
| 缓冲 | 2GB 文件缓冲 + 无限重试 | VictoriaLogs 重启不丢日志 |
| 多行 | CRI parser | 正确合并 Java 异常栈 |

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
# 查看组件状态
kubectl get pods -n monitoring
kubectl get svc -n monitoring
kubectl get daemonset -n monitoring

# 日志写入确认
kubectl exec -n monitoring victoria-logs-0 -- sh -c \
  'wget -q -O- http://127.0.0.1:9428/metrics | grep vl_bytes_ingested_total'

# Fluent Bit 数据流确认
kubectl logs -n monitoring -l app.kubernetes.io/name=fluent-bit --tail=3 | grep "HTTP status=200"

# 插件确认
kubectl exec -n monitoring -l app.kubernetes.io/name=grafana -- sh -c \
  'ls /var/lib/grafana/plugins/victoriametrics-logs-datasource/plugin.json'

# 在 Grafana Explore 中查询日志
# 切换数据源为 VictoriaLogs，输入 LogsQL：
#   namespace:monitoring and error
#   namespace:mysql
```

## 访问地址

| 服务 | 方式 | 地址 |
|------|------|------|
| Grafana | 域名 | http://monitor.czw-sre.internal（需 hosts 指向 192.168.5.240） |
| Grafana | NodePort | http://\<任一节点IP\>:30002 |
| Grafana | 默认账号 | admin / admin123 |
| VictoriaLogs | 集群内 | http://victoria-logs.monitoring:9428 |
| Fluent Bit | 集群内 | 每节点 :2020（HTTP 监控端口） |

## 日志查询快速入门（LogsQL）

```logsql
# 基本过滤
error and namespace:mysql
namespace:pg17 and "ERROR"
namespace:monitoring and not "healthcheck"

# 查看特定容器
container_name:fluent-bit
container_name:victoria-logs and "error"

# 时间范围（配合 Grafana 时间选择器）
```

## 重要说明

- 详细部署记录和踩坑日志见 **[DEPLOYMENT.md](./DEPLOYMENT.md)**
- VictoriaLogs v1.49.0 起**已移除 Loki 兼容接口**，必须用官方 Grafana 插件
- 插件为未签名，已配置 `allow_loading_unsigned_plugins`
- 首次部署若插件未自动安装，运行 `./plugins/download-plugin.sh --install`
- 全部组件幂等部署，重复执行不会破坏现有配置
- Grafana 默认密码 `admin123`，首次部署后请及时修改
