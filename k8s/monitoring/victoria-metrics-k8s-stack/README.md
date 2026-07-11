# victoria-metrics-k8s-stack

VictoriaMetrics 生态栈：VMSingle（指标存储）+ VMAgent（指标采集）+ VMAlert（告警）+ Grafana（展示）+ VictoriaLogs（日志聚合）+ vlagent（日志采集）。

## 架构

| 组件 | 来源 | 存储 | 说明 |
|------|------|------|------|
| victoria-metrics-k8s-stack | Nexus (0.85.2 / app v1.146.0) | PVC (nfs-client, 10Gi) | VMSingle + VMAgent + VMAlert + Grafana + CRDs |
| VictoriaLogs | Nexus (0.13.8 / app v1.51.0) | PVC (nfs-client, 10Gi) | 单实例日志存储 |
| vlagent | Nexus (0.3.6 / app v1.51.0) | — | DaemonSet，采集所有节点日志 |

## 访问入口

| 服务 | 地址 | 凭证 |
|------|------|------|
| Grafana-VM | https://vm-grafana.czw-sre.internal | admin / admin |
| VMSingle | https://vm-metrics.czw-sre.internal | 无认证（内网域名） |
| VictoriaLogs | https://vm-logs.czw-sre.internal | 无认证 |

## 部署

```bash
bash install.sh
```

## 卸载

```bash
bash uninstall.sh
```

## Prometheus 兼容

VM Operator 默认启用 Prometheus 转换器（`disable_prometheus_converter: false`），会自动将 Prometheus ServiceMonitor/PodMonitor CRD 转换为 VMServiceScrape，实现无缝迁移。

VMAgent 配置了 `selectAllByDefault: true`，自动发现所有命名空间中的 VMServiceScrape。

## 数据源

Grafana 已预置 VictoriaMetrics 数据源，自动安装默认 Dashboard。

## 注意事项

- k3s 内置 etcd/kubeControllerManager/kubeScheduler 不可用，已禁用
- Helm release 名称：`victoriametrics`、`victorialogs`、`vmlogs-collector`
