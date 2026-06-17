# Docker Compose — Local Development

Docker Compose configurations for local development and CI environments.

These are the Docker Compose equivalents of the K8s deployments in `k8s/`. Use compose for local dev, K8s for production.

## Services

| Service | Path | Description |
|---------|------|-------------|
| MySQL 5.7 | `mysql-5.7/` | Legacy MySQL |
| MySQL 8.4 | `mysql-8.4/` | Current MySQL |
| PostgreSQL 15 | `postgresql-15/` | PostgreSQL |
| Redis | `redis/` | Redis cache |
| Valkey | `valkey/` | Redis-compatible alternative |
| DragonflyDB | `dragonflydb/` | High-performance cache |
| MinIO | `minio/` | S3-compatible storage |
| Nginx | `nginx/` | Reverse proxy |
| ACME.sh | `acme.sh/` | SSL certificate automation |
| QuestDB | `questdb/` | Time-series database |
| ZOT | `zot/` | OCI registry |
| Monitor | `monitor/` | Prometheus + Grafana + VictoriaLogs stack |

## Quick Start

```bash
# Start all services
docker compose -f mysql-8.4/docker-compose.yml up -d

# Or start the monitoring stack
docker compose -f monitor/docker-compose.yml up -d
```

## Structure

Each service follows:

```
service/
├── README.md       # Usage, ports, env vars
├── docker-compose.yml
├── conf/           # Configuration files
└── .env.example    # Environment variable template
```

## Notes

- All images pin specific versions for reproducibility
- Data persistence via named volumes or bind mounts
- Network mode: bridge (default), override via `.env`
