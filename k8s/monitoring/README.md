# Monitoring — Prometheus + Grafana + VictoriaLogs

Observability stack for Kubernetes clusters.

## Versions

| Component | Version | Source |
|-----------|---------|--------|
| kube-prometheus-stack | 85.1.3 | `prometheus-community/kube-prometheus-stack` |
| Grafana | latest | included in chart |
| VictoriaLogs | 1.x | `docker.io/victoriametrics/victoria-logs` |

## Deploy

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f helm-values.yaml
```

## Components

- **Prometheus**: Metrics collection & alerting
- **Grafana**: Dashboards with custom dashboards in `dashboards/`
- **VictoriaLogs**: Lightweight log storage (Docker Compose for dev, StatefulSet for prod)
- **FluentBit**: Log shipping via DaemonSet
- **AlertManager**: Alert routing & notification
