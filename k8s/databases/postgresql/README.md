# PostgreSQL 17

PostgreSQL deployment on Kubernetes with CloudNative PG operator.

## Versions

| Component | Version |
|-----------|---------|
| PostgreSQL Image | ghcr.io/cloudnative-pg/postgresql:17 |
| CloudNative PG Operator | 0.28.2 |

## Deploy

```bash
# Install operator
kubectl apply -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-0.28/releases/cnpg-0.28.2.yaml

# Apply cluster CR
kubectl apply -f operator/standalone/
```

## Structure

| Path | Description |
|------|-------------|
| `operator/standalone/` | Single instance CR + external service |
| `operator/ha/` | High-availability cluster CR |

## Monitoring

CloudNative PG includes built-in Prometheus metrics. Import the Grafana dashboard from:

https://github.com/cloudnative-pg/cloudnative-pg
