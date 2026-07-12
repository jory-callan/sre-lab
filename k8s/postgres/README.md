# PostgreSQL 17

CloudNativePG 实例，默认 **1 主 2 从 HA**，S3 备份至 MinIO。

| 项目 | 值 |
|------|-----|
| Operator | [CNPG](../operators/cnpg/) 1.29.1 |
| 实例命名空间 | `postgres` |
| 镜像 | `ghcr.io/cloudnative-pg/postgresql:17`（完整版 47 扩展） |

## 部署

```bash
# 1. 先装 operator（仅首次）
bash ../operators/cnpg/install.sh

# 2. 部署实例
bash install.sh              # 1 主 2 从（默认）
bash install.sh standalone   # 单节点
```

> 依赖 MinIO（`dep-minio/` 目录），`install.sh` 自动创建备份桶和凭证。

## 目录

| 路径 | 说明 |
|------|------|
| `cr/ha/` | HA 集群 CR（1主2从 + 定时备份） |
| `cr/standalone/` | 单节点 CR |
| `dep-minio/` | **MinIO 依赖**（S3 凭证、Policy），install.sh 自动配置 |
| `monitor/` | Grafana Dashboard + 告警规则 |
| `DELIVERY.md` | 开发对接文档（连接/凭证/规格/备份恢复） |
| `drill-backup-restore.md` | 备份恢复演练 |
| `tuning-guide.md` | **生产调优指南**（4c8g/PgBouncer/50k 并发/SSD 优化） |

> 详细交付信息 → [DELIVERY.md](DELIVERY.md)
