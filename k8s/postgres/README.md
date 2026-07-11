# PostgreSQL 17

PostgreSQL deployment on Kubernetes with CloudNative PG operator。

| 项目 | 值 |
|------|-----|
| Operator 命名空间 | `operators`（见 `../operators/cnpg/`） |
| 实例命名空间 | `postgres` |
| PostgreSQL 镜像 | ghcr.io/cloudnative-pg/postgresql:17 |
| CNPG Operator | 0.28.2 |
| 默认密码 | `postgres` / `postgres@123` |

## 部署

```bash
# 1. 先安装 operator（仅首次）
bash ../operators/cnpg/install.sh

# 2. 部署实例
bash install.sh standalone    # 单节点
bash install.sh ha            # 3 节点 HA
```

## 连接

| 模式 | Host | Port |
|------|------|------|
| 集群内读写 | `pg-standalone-rw.postgres.svc` / `pg-ha-rw.postgres.svc` | 5432 |
| 外部 NodePort | `<node-ip>` | 30205 (standalone) / 30006 (HA) |
| 用户 | `postgres` | |
| 密码 | `postgres@123` | |

## 目录

| 路径 | 说明 |
|------|------|
| `operator/standalone/` | 单实例 CR + 外部 Service |
| `operator/ha/` | HA 集群 CR + 外部 Service |
| `operator/common/` | 公共 Secret（数据库密码） |
