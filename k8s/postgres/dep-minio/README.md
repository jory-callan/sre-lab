# MinIO 依赖

PostgreSQL S3 备份需要 MinIO 提供桶和凭证。由 `install.sh` 自动配置。

| 文件 | 说明 |
|------|------|
| `backup-policy.json` | MinIO IAM Policy，限制 `pg-backup` 用户只可操作 `postgres-backup` 桶 |
| `pg-s3-creds.yaml` | S3 凭证 Secret（`pg-s3-creds`），`cluster.yaml` 引用此 Secret |
| `setup.sh` | 建桶、建用户、attach Policy（mc 操作，可独立重跑） |
