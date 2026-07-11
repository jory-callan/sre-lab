# MinIO 依赖

PostgreSQL S3 备份依赖的 MinIO 资源。由 `install.sh` 自动配置。

| 文件 | 说明 |
|------|------|
| `backup-policy.json` | MinIO IAM Policy，限制 `pg-backup` 用户只能操作 `postgres-backup` 桶 |
| `pg-s3-creds.yaml` | S3 凭证 Secret（`pg-s3-creds`），`cluster.yaml` 的 `barmanObjectStore` 引用此 Secret |
