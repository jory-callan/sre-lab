# PostgreSQL 交付说明

> CloudNativePG 17 集群，S3 备份至 MinIO。本文档面向**对接开发者**。
>
> **生产调优版**：4c8g、50,000 并发客户端（PgBouncer 池化）、SSD WAL 优化。
> 调优详情 → [tuning-guide.md](tuning-guide.md)

---

## 连接方式

| 位置 | 用途 | Host | Port |
|------|------|------|------|
| **集群内部（推荐）** | **读写**（主库，经 Pooler） | `pg-ha-rw.pooler.postgres.svc` | 5432 |
| 集群内部 | **只读**（从库，经 Pooler） | `pg-ha-ro.pooler.postgres.svc` | 5432 |
| 集群内部 | **管理调试**（直连主库，绕开 Pooler） | `pg-ha-rw.postgres.svc` | 5432 |
| 集群内部 | 管理调试（直连从库） | `pg-ha-ro.postgres.svc` | 5432 |
| 集群外部 | 管理调试 | `<node-ip>` | 30006 |

> ⚠️ **应用始终用 Pooler Service 连接**（`*.pooler.postgres.svc`），绕过 Pooler 直连会占用 `max_connections: 500` 的 PG 后端槽位，不建议用于业务流量。

### 连接字符串

```text
# JDBC（通过 Pooler）
jdbc:postgresql://pg-ha-rw.pooler.postgres.svc:5432/postgres

# Python (psycopg2)
host=pg-ha-rw.pooler.postgres.svc port=5432 dbname=postgres

# Go (pgx) / GORM（通过 Pooler）
postgres://postgres:<password>@pg-ha-rw.pooler.postgres.svc:5432/postgres?sslmode=disable

# psql 直连调试（绕开 Pooler）
psql -h pg-ha-rw.postgres.svc -U postgres -d postgres
```

---

## 凭证

### 认证方式

| 用户 | 角色 | 密码来源 |
|:----|:----|:--------|
| `postgres` | 超级用户（数据库 owner） | `pg-auth-secret`（首次部署指定） |

```bash
# 获取密码
kubectl get secret pg-auth-secret -n postgres -o jsonpath='{.data.password}' | base64 -d
```

> `pg-auth-secret` 由部署时指定，CNPG bootstrap 阶段读取并初始化。后续密码变更需在 Secret 和 PG 内同时操作。

### 连接参数

| 参数 | 值 |
|------|-----|
| 数据库 | `postgres` |
| 超级用户 | `postgres`（owner） |
| 密码 | 见 `pg-auth-secret` |

---

## 架构

### 拓扑

```
┌──────────────────────────────────────────────────────────────────┐
│                    pg-ha (Cluster — 3 nodes)                      │
│                                                                   │
│   ┌──────────┐    ┌──────────┐    ┌──────────┐                   │
│   │ pg-ha-1  │◄───│ pg-ha-2  │◄───│ pg-ha-3  │  streaming repl  │
│   │ PRIMARY  │    │ REPLICA  │    │ REPLICA  │                   │
│   │ 10Gi PVC │    │ 10Gi PVC │    │ 10Gi PVC │                   │
│   │ 5Gi WAL  │    │ 5Gi WAL  │    │ 5Gi WAL  │                   │
│   └────┬─────┘    └──────────┘    └──────────┘                   │
│        │                                                          │
│   ┌────┴──────────────────────────────────────────────────┐      │
│   │   Service 路由                                        │      │
│   │   pg-ha-rw  → PRIMARY（读写直连，绕过 Pooler）         │      │
│   │   pg-ha-ro  → REPLICAs（只读直连）                     │      │
│   └───────────────────────────────────────────────────────┘      │
│                                                                   │
│   ┌──────────────────────────────────────────────────────────┐   │
│   │   PgBouncer Pooler（2 实例·transaction 模式）              │   │
│   │   pg-ha-rw.pooler  → 主库（50,000 客户端→200 PG 后端）    │   │
│   │   pg-ha-ro.pooler  → 从库（只读流量）                     │   │
│   └──────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────┘
```

### 设计要点

- **连接池化**：PgBouncer × 2 实例，`transaction` 模式
  - 50,000 客户端连接 → PgBouncer 复用为 ~400 条 PG 连接
  - `max_client_conn` 每 Pooler 25,000，总计 50,000
  - `default_pool_size` 每 Pooler 200，总计 400
- **同步复制**：`minSyncReplicas: 1`，写入至少确认 1 个从库
- **故障转移**：CNPG Operator 自动选举新主，Pooler 自动重连

### 故障转移

当主库不可用时，CNPG 自动选举一个新主库：
1. Operator 检测到主库失联
2. 选择一个同步延迟最小的从库提升为主
3. `pg-ha-rw` 和 Pooler Service 自动切到新主库
4. PgBouncer 检测到连接断开并自动重建连接池
5. **应用无需重试**（通过 Pooler 连接时）

---

## 资源规格

### Pod 资源

| 组件 | Request | Limit | 说明 |
|:----|:-------:|:-----:|:-----|
| PostgreSQL 实例 | 不设置（超卖） | **4c / 8Gi** | 3 实例各保留故障转移能力 |
| PgBouncer Pooler | 100m / 128Mi | 500m / 512Mi | 2 实例 HA |

### 存储

| 项 | 值 |
|----|-----|
| 数据 PVC（每实例） | 10Gi，StorageClass `local-path` |
| WAL PVC（每实例，独立） | 5Gi，StorageClass `local-path` |
| 总数据容量 | 30Gi（3 × 10Gi） |
| 总 WAL 容量 | 15Gi（3 × 5Gi） |

### 命名空间配额

| 资源 | 上限 | 说明 |
|:----|:----|:------|
| Pod | 15 | 3 PG + 2 Pooler + 备份 Job 等 |
| CPU Request | 4 核 | 超卖运行 |
| 内存 Request | 8Gi | |
| CPU Limit | 16 核 | 3×4c + 2×0.5c + 余量 |
| 内存 Limit | 32Gi | 3×8Gi + 2×0.5Gi + 余量 |
| PVC | 15 | 3×2（data+wal）+ 余量 |

---

## 性能上限估算

| 维度 | 上限 | 瓶颈因素 |
|:----|:----:|:---------|
| **客户端并发连接** | **50,000** | PgBouncer `max_client_conn: 25000 × 2` |
| PG 后端连接 | 500 | `max_connections: 500`（池化后） |
| 只读查询吞吐 | 2× replica 分摊 | 每个 replica 4c / 8Gi |
| 写入吞吐 | ~单节点能力 | 同步复制至少 1 从库确认 |
| 内存 | 8Gi/实例 | `shared_buffers=2GB`，连接 ~2.5GB，OS ~2GB |
| 存储 | 10Gi 数据 + 5Gi WAL | PVC 容量（可在线扩容） |
| 慢查询阈值 | 1s 记录 | `log_min_duration_statement=1000` |

> 生产环境实际吞吐取决于工作负载模型。建议部署后通过 pg_stat_statements + Grafana 持续观察。

---

## 备份与恢复

### 备份策略

> 💡 完整的备份恢复操作演练见 [drill-backup-restore.md](drill-backup-restore.md)。

| 类型 | 频率 | 保留策略 |
|:----|:------|:---------|
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

#### 存储估算

| 项目 | 日增量（估算） | 30 天总量 |
|:----|:--------------|:---------|
| 全量备份（gzip 压缩，10Gi DB → ~4Gi） | ~4Gi | ~120Gi |
| WAL（gzip 压缩，取决于写入量） | ~0.5-2Gi | ~15-60Gi |
| **合计** | | **~135-180Gi** |

> 实际用量取决于数据库写入量。WAL 写入量可以通过 `pg_stat_wal` 监控。建议定期检查 MinIO `postgres-backup` bucket 用量。

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
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: pg-ha-restored
  namespace: postgres
spec:
  instances: 3
  imageName: ghcr.io/cloudnative-pg/postgresql:17
  storage:
    size: 10Gi
    storageClass: local-path
  walStorage:
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
kubectl exec -n postgres -it pg-ha-restored-1 -- psql -U postgres -d postgres -c "SELECT count(*) FROM ..."
```

> **注意**：恢复是一个**新集群**，原集群继续运行。确认恢复成功后再切换流量。

---

## 监控

- **PodMonitor**: CNPG 自动创建（`monitoring.enablePodMonitor: true`），VMAgent 每 20s 抓取
- **Grafana Dashboard**: 官方原版 JSON 见 `monitor/dashboard/cnpg-cluster.json`
  - 一键导入: `bash monitor/import-dashboard.sh`
- **告警规则**: 7 条内置规则（install.sh 自动安装，见 `monitor/rule/cnpg-alerts.yaml`）
- **关键指标**:
  - `cnpg_pg_stat_database_xact_commit` / `rollback` — 事务量
  - `cnpg_pg_replication_lag` — 复制延迟
  - `cnpg_backends_total` — 连接数
  - `cnpg_pg_database_size_bytes` — 数据库大小
  - `pg_stat_statements` — 慢查询 / 高频查询识别

---

## 故障排查

| 现象 | 原因 | 解决 |
|:----|:-----|:------|
| 连接被拒绝 | 用错 Service 或端口 | 应用用 `*.pooler.postgres.svc:5432` |
| `password authentication failed` | 密码错误 | `kubectl get secret pg-auth-secret -n postgres -o jsonpath='{.data.password}' \| base64 -d` |
| 写入超时 | 主库压力大或从库同步延迟 | 检查 `pg_replication_lag`，或降低 `maxSyncReplicas` |
| 主库宕机后无法连接 | 故障转移未完成 | 等待 10-30s，Pooler 自动重建连接 |
| PVC 空间不足 | `local-path` 存储满 | 扩容 PVC（10Gi 数据 / 5Gi WAL）或清理旧数据 |
| 备份失败 | MinIO 不可达 | `kubectl -n minio get pods` 检查 MinIO 状态 |
| `bas too many clients` | PG 后端连接满 | 检查 Pooler `max_db_connections` + PG `max_connections` |
| `cluster in recovery` 错误 | 应用连到了只读节点 | 确认应用使用的是 rw（读写）而非 ro Service |
