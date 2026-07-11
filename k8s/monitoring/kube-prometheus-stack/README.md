# kube-prometheus-stack

Prometheus Operator 生态栈：Prometheus（指标采集）+ Loki（日志聚合）+ Promtail（日志采集）+ Grafana（展示）。

## 架构

| 组件 | 来源 | 存储 | 说明 |
|------|------|------|------|
| kube-prometheus-stack | GitHub Release (69.7.4) | PVC (nfs-client, 10Gi) | Prometheus Operator + Prometheus + Grafana + CRDs |
| Loki | Nexus (6.32.0) | S3 (MinIO `loki` bucket) | SingleBinary 模式，日志聚合 |
| Promtail | Nexus (6.16.6) | — | DaemonSet，采集所有节点日志 |

## 访问入口

| 服务 | 地址 | 凭证 |
|------|------|------|
| Grafana | https://grafana.czw-sre.internal | admin / admin |
| Loki API | https://loki.czw-sre.internal | 无认证 |

## 部署

```bash
bash install.sh
```

## 卸载

```bash
bash uninstall.sh
```

## 数据源

Grafana 已预置 Loki 数据源（`loki-gateway:80`），Prometheus 数据源由 kube-prometheus-stack 自动配置。

## ServiceMonitor 兼容

Prometheus 通过 `release: kps` 标签匹配 ServiceMonitor，并配置了 `serviceMonitorNamespaceSelector: {}`（跨命名空间发现）。其他命名空间的 ServiceMonitor 添加 `release: kps` 标签即可被自动发现。
