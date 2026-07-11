# PostgreSQL 17

PostgreSQL deployment on Kubernetes with CloudNative PG operator.

## Versions

| Component | Version |
|-----------|---------|
| PostgreSQL Image | ghcr.io/cloudnative-pg/postgresql:17 |
| CloudNative PG Operator | 0.28.2 |

## Deploy

```bash
# 安装 operator（自动处理，仅首次需要）
./install.sh standalone    # 单节点
./install.sh ha            # 3 节点 HA
```

## Structure

| Path | Description |
|------|-------------|
| `operator/standalone/` | Single instance CR + external service (ns: postgresql) |
| `operator/ha/` | High-availability cluster CR (ns: postgresql) |

## Connection

| Mode | Host | Port |
|------|------|------|
| Cluster internal (rw) | `pg-standalone-rw.postgresql.svc` / `pg-ha-rw.postgresql.svc` | 5432 |
| External (NodePort) | `<node-ip>` | 30205 (standalone) / 30006 (HA) |
| Password | `pg@czw` | |

## Monitoring

CloudNative PG includes built-in Prometheus metrics. Import the Grafana dashboard from:

https://github.com/cloudnative-pg/cloudnative-pg
