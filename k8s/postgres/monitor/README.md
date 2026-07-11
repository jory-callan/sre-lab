# PostgreSQL Monitor

| 路径 | 来源 | 说明 |
|------|------|------|
| `dashboard/cnpg-cluster.json` | [CNPG grafana-dashboards](https://github.com/cloudnative-pg/grafana-dashboards) | 官方原版，66 面板全量指标，用 import-dashboard.sh 导入 |
| `rule/cnpg-alerts.yaml` | [CNPG docs/samples](https://github.com/cloudnative-pg/cloudnative-pg/blob/main/docs/src/samples/monitoring/prometheusrule.yaml) | PrometheusRule 格式，install.sh 自动安装 |
| `import-dashboard.sh` | — | 一键导入 Dashboard 至 Grafana（API 自动映射数据源） |
