# PostgreSQL 交付说明

> CloudNativePG 17 集群，S3 备份至 MinIO。本文档面向**对接开发者**。

---

## 连接方式

| 位置 | 用途 | Host | Port |
|------|------|------|------|
| 集群内部 | **读写**（主库） | `pg-ha-rw.postgres.svc` | 5432 |
| 集群内部 | **只读**（从库） | `pg-ha-ro.postgres.svc` | 5432 |
| 集群内部 | 负载均衡 | `pg-ha-r.postgres.svc` | 5432 |
| 集群外部 | 管理调试 | `<node-ip>` | 30006 |

> ⚠️ **应用始终用内部 Service 连接**，NodePort 仅用于开发调试。

### 连接字符串

```text
# JDBC
jdbc:postgresql://pg-ha-rw.postgres.svc:5432/appdb

# Python (psycopg2)
host=pg-ha-rw.postgres.svc port=5432 dbname=appdb

# Go (pgx) / GORM
postgres://app:<password>@pg-ha-rw.postgres.svc:5432/appdb?sslmode=disable

# psql
psql -h pg-ha-rw.postgres.svc -U postgres -d appdb
```

---

## 凭证

### 密码获取

CNPG 启动后自动生成随机密码并存入 Kubernetes Secret：

```bash
# 应用用户（app，默认 owner 数据库 appdb）
kubectl get secret pg-ha-app -n postgres -o jsonpath='{.data.password}' | base64 -d

# superuser（postgres 超级用户）
kubectl get secret pg-ha-superuser -n postgres -o jsonpath='{.data.password}' | base64 -d
```

> 首次部署时指定了初始密码，CNPG 接管后可能自动轮换。**不要依赖硬编码密码**，始终从 Secret 读取。

### 连接参数

| 参数 | 值 |
|------|-----|
| 数据库 | `appdb` |
| 应用用户 | `app`（owner），密码见 `pg-ha-app` Secret |
| 超级用户 | `postgres`，密码见 `pg-ha-superuser` Secret |

---

## 架构

```
┌─────────────────────────────────────────────────────┐
│                    pg-ha (Cluster)                   │
│                                                      │
│   ┌──────────────┐    ┌──────────────┐              │
│   │  pg-ha-1     │◄───│  pg-ha-2     │  replicas    │
│   │  PRIMARY     │    │  REPLICA     │              │
│   │  5Gi local   │    │  5Gi local   │              │
│   └──────┬───────┘    └──────────────┘              │
│          │                                           │
│   ┌──────┴───────┐                                   │
│   │  pg-ha-3     │  replica                          │
│   │  REPLICA     │                                   │
│   │  5Gi local   │                                   │
│   └──────────────┘                                   │
│                                                      │
│   ┌─ Services ───────────────────────────────────┐   │
│   │  pg-ha-rw  → PRIMARY (读写)                   │   │
│   │  pg-ha-ro  → REPLICAs (只读轮询)              │   │
│   │  pg-ha-r   → ALL (读写分离需应用层控制)       │   │
│   └───────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

### 故障转移

当主库不可用时，CNPG 自动选举一个新主库：
1. Operator 检测到主库失联
2. 选择一个同步延迟最小的从库提升为主
3. `pg-ha-rw` Service 自动切到新主库
4. 应用端连接池会自动重连（**建议应用侧配置连接池重试**）

---

## 资源规格

### Pod 资源

| 资源 | Request | Limit |
|------|---------|-------|
| CPU | 100m | 500m |
| 内存 | 256Mi | 512Mi |

### 存储

| 项 | 值 |
|----|-----|
| 每个实例 | 5Gi，StorageClass `local-path` |
| 总容量 | 15Gi（3 × 5Gi） |
| 数据目录 | `/var/lib/postgresql/data` (PVC) |
| WAL 目录 | 与数据同卷（未独立 PVC） |

### 命名空间配额

| 资源 | 上限 |
|------|------|
| Pod | 10 |
| CPU Request | 2 核 |
| 内存 Request | 4Gi |
| PVC | 10 |

> 3 节点 HA 实际占用 3 Pod + 3 PVC，剩余可容纳 1 个额外部署。

---

## 性能上限估算

| 维度 | 上限 | 瓶颈因素 |
|------|------|---------|
| 最大连接数 | 300 | `max_connections` 配置 + Pod 内存 512Mi |
| 存储上限 | 15Gi（单实例 5Gi） | PVC 容量 |
| 只读查询吞吐 | 2× replica 分摊 | 每个 replica CPU 500m |
| 写入吞吐 | ~单节点能力 | 同步复制至少 1 个从库确认 |
| 并发连接 | ~100-150 活跃 | 512Mi 内存下每个连接约 3-5Mi |

> 开发/测试环境估算值。生产环境建议增加 CPU/内存、独立 WAL 卷、开启连接池（PgBouncer）。

---

## 备份与恢复

### 备份策略

> 💡 完整的备份恢复操作演练见 [drill-backup-restore.md](drill-backup-restore.md)。

| 类型 | 频率 | 保留策略 |
|------|------|---------|
| 全量备份 | 每天 03:00 | 30 天，超期自动删除 |
| WAL 归档 | 持续实时 | 最多 7 天，与全量备份联动清理 |

#### 保留策略工作原理

```text
保留窗口 30 天（retentionPolicy: "30d"）
├── 全量备份：保留最近 30 天内
│    第 31 天 → 最老的备份自动删除
│
└── WAL：保留"恢复 30 天内任一备份所需"的 WAL
     额外安全阀：WAL 本身最多保留 7 天（maxAge: 7d）
     防止写入量暴增时 WAL 失控
```

> **WAL 不独立保留**。它的生命周期取决于全量备份——最老的全量备份过期后，对应的 WAL 也一并清理。`maxAge: 7d` 是额外安全阀：即使备份保留策略认为某个 WAL"还需要"，超过 7 天的也会强制删除，防止因 bug 或异常写入导致存储无限增长。

#### 存储估算

| 项目 | 日增量（估算） | 30 天总量 |
|------|---------------|----------|
| 全量备份（gzip 压缩，5Gi DB → ~2Gi） | ~2Gi | ~60Gi |
| WAL（gzip 压缩，取决于写入量） | ~0.5-2Gi | ~15-60Gi |
| **合计** | | **~75-120Gi** |

> 实际用量取决于数据库写入量。WAL 写入量可以通过 `pg_stat_wal` 监控。如果 DB 写入量很小，WAL 可能每天只有几十 MiB。建议定期检查 MinIO `postgres-backup` bucket 用量。

备份目标：MinIO `postgres-backup` bucket（同集群内）。

### 手动触发备份

```bash
kubectl cnpg backup pg-ha -n postgres
```

### 查看备份列表

```bash
kubectl get backup -n postgres
```

### 从备份恢复

恢复 = 创建一个新 Cluster，指定从已有的 S3 备份恢复：

```yaml
# 示例：创建 pg-ha-restored 从备份恢复
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: pg-ha-restored
  namespace: postgres
spec:
  instances: 3
  imageName: ghcr.io/cloudnative-pg/postgresql:17-minimal-trixie
  storage:
    size: 5Gi
    storageClass: local-path

  # ── 指定恢复来源 ─────────────────────────
  bootstrap:
    recovery:
      backup:
        name: <backup-name>    # 从 kubectl get backup 查看
      # 或恢复到指定时间点（PITR）
      # recoveryTarget:
      #   targetTime: "2026-07-11 14:30:00"

  # ── 仍需引用 S3 凭证 ─────────────────────
  backup:
    barmanObjectStore:
      destinationPath: s3://postgres-backup/
      endpointURL: http://minio.minio.svc:80
      s3Credentials:
        accessKeyId:
          name: pg-s3-creds
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: pg-s3-creds
          key: ACCESS_SECRET_KEY
```

恢复步骤：

```bash
# 1. 找到要恢复的备份
kubectl get backup -n postgres

# 2. 创建恢复 Cluster CR
kubectl apply -f restore-cluster.yaml

# 3. 验证恢复
kubectl get cluster -n postgres
kubectl logs -n postgres -l cnpg.io/cluster=pg-ha-restored -c postgres

# 4. 确认数据
kubectl exec -n postgres -it pg-ha-restored-1 -- psql -U postgres -d appdb -c "SELECT count(*) FROM ..."
```

> **注意**：恢复是一个**新集群**，原集群继续运行。确认恢复成功后再切换流量。

---

## 监控

- **PodMonitor**: CNPG 自动创建，Prometheus 每 15s 抓取
- **Grafana**: 监控栈已预置 CNPG 仪表盘（`grafana_dashboard=postgresql`）
- **关键指标**:
  - `pg_stat_database_xact_commit` / `rollback` — 事务量
  - `pg_replication_lag` — 复制延迟
  - `pg_stat_database_numbackends` — 连接数
  - `pg_database_size_bytes` — 数据库大小

---

## 故障排查

| 现象 | 原因 | 解决 |
|------|------|------|
| 连接被拒绝 | 用错 Service 或端口 | 内部用 `pg-ha-rw.postgres.svc:5432` |
| `password authentication failed` | 密码过期或读错 Secret | `kubectl get secret pg-ha-app -o jsonpath='{.data.password}' \| base64 -d` |
| 写入超时 | 主库压力大或从库同步延迟 | 检查 `pg_replication_lag`，考虑扩容 |
| 主库宕机后无法连接 | 故障转移还未完成 | 等待 10-30s，客户端配置重试逻辑 |
| PVC 空间不足 | `local-path` 存储满 | 扩容 PVC 或清理旧数据 |
| 备份失败 | MinIO 不可达 | `kubectl -n minio get pods` 检查 MinIO 状态 |
| `cluster in recovery` 错误 | 应用连到了只读节点 | 用 `pg-ha-rw`（读写）而非 `pg-ha-ro` |
