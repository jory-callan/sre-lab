# PostgreSQL 17

CloudNativePG 实例，默认 **1 主 2 从 HA**，S3 备份至 MinIO。

| 项目 | 值 |
|------|-----|
| Operator | [CNPG](operator/) 1.29.1 |
| 实例命名空间 | `postgres` |
| 镜像 | `ghcr.io/cloudnative-pg/postgresql:17`（完整版 47 扩展） |

## 部署

```bash
# 1. 先装 operator（仅首次）
bash operator/install.sh

# 2. 部署实例
bash cr-ha/install.sh        # 1 主 2 从（默认）
bash cr-standalone/install.sh # 单节点
```

> 依赖 MinIO（实例目录内 `dep-minio-*` 文件），`install.sh` 自动创建备份桶和凭证。

## 目录

| 路径 | 说明 |
|------|------|
| `cr-ha/` | HA 集群 CR（1主2从 + 定时备份） |
| `cr-standalone/` | 单节点 CR |
| `common/` | Grafana Dashboard + 告警规则 |
| `tuning-guide.md` | **生产调优指南**（4c8g/PgBouncer/50k 并发/SSD 优化） |
| `DELIVERY.md` | 开发对接文档（连接/凭证/规格/备份恢复） |
| `drill-backup-restore.md` | 备份恢复演练 |

> 详细交付信息 → [DELIVERY.md](DELIVERY.md)
