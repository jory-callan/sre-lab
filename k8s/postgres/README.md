# PostgreSQL 17

PostgreSQL deployment on Kubernetes with CloudNative PG operator。默认 **1 主 2 从 HA** 部署，S3 备份至 MinIO。

| 项目 | 值 |
|------|-----|
| Operator 命名空间 | `operators`（见 `../operators/cnpg/`） |
| 实例命名空间 | `postgres` |
| PostgreSQL 镜像 | ghcr.io/cloudnative-pg/postgresql:17 |
| CNPG Operator | 0.28.2 |
| 默认模式 | 1 主 2 从（HA） |

## 交付

> 开发对接请直接看 [DELIVERY.md](DELIVERY.md) — 含 Endpoint、凭证、资源规格、备份恢复、故障排查。

## 部署

```bash
# 1. 先安装 operator（仅首次）
bash ../operators/cnpg/install.sh

# 2. 部署实例（默认 HA）
bash install.sh              # 1 主 2 从
bash install.sh standalone   # 单节点
```

> 首次部署 HA 后约 2-3 分钟集群就绪。

## 备份

S3 备份配置已集成：

- **存储**: MinIO `postgres-backup` bucket（集群内 `minio.minio.svc:80`）
- **策略**: 每天 03:00 全量备份，保留 30 天，WAL 持续归档
- **手动**: `kubectl cnpg backup pg-ha -n postgres`

## 目录

| 路径 | 说明 |
|------|------|
| `operator/standalone/` | 单实例 CR + 外部 Service |
| `operator/ha/` | HA 集群 CR + 外部 Service + 定时备份 |
| `operator/common/` | 公共 Secret（数据库密码 + S3 凭证） |
| `DELIVERY.md` | 开发交付文档 |
| `backup-policy.json` | MinIO 备份用户 Policy |
| `drill-backup-restore.md` | 备份恢复演练文档（删表 → 恢复） |
| `踩坑记录.md` | 历史踩坑记录 |
