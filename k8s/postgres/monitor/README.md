# PostgreSQL Monitor

| 路径 | 来源 | 说明 |
|------|------|------|
| `dashboard/cnpg-cluster.json` | [CNPG grafana-dashboards](https://github.com/cloudnative-pg/grafana-dashboards) | 官方原版，66 面板全量指标，需手动 Import |
| `rule/cnpg-alerts.yaml` | [CNPG docs/samples](https://github.com/cloudnative-pg/cloudnative-pg/blob/main/docs/src/samples/monitoring/prometheusrule.yaml) | PrometheusRule 格式，install.sh 自动安装 |
