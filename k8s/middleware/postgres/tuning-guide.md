# PostgreSQL 生产调优指南

> CloudNativePG 17 集群（HA 3 节点）— 4c8g 规格，SSD 本地存储
> 目标：支持 50000 并发客户端连接，生产级配置。

---

## 1. 架构总览

### 1.1 连接分层

```text
          客户端连接（50,000）
               │
               ▼
  ┌─────────────────────────────────┐
  │     PgBouncer Pooler × 2        │  ← 50,000 个客户端连接（每个 ~2KB）
  │     transaction 模式             │     无认证时仅消耗极少量内存
  └──────────┬──────────────────────┘
             │
  ┌──────────┴──────────────────────┐
  │  PostgreSQL 后端连接（~400）     │  ← 每个后端 ~5-10MB
  │  max_connections: 500            │     总计 ~2.5-4GB
  └─────────────────────────────────┘
```

**关键约束：PostgreSQL 的 `max_connections` 和 8Gi 内存**

PostgreSQL 中每个后端连接在进程私有内存中消耗约 5-10MB（含事务上下文、排序暂存等），并共享一部分缓冲池。

| max_connections | 连接内存估算 | 8Gi 是否可行 |
|:--------------:|:-----------:|:-----------:|
| 500 | ~2.5-4GB | ✅ 可行 |
| 1000 | ~5-8GB | ⚠️ 紧张 |
| 5000 | ~25-40GB | ❌ 不可行 |
| 50000 | ~250-500GB | ❌ 不可行 |

因此 **PgBouncer 事务连接池是必须的** — 它实现了"客户端 50,000 并发"的目标：

```
50,000 客户端连接 → PgBouncer（复用成 ~400 条 PG 后端连接）→ PostgreSQL
```

每个 PgBouncer 客户端连接仅消耗约 2KB 内存，50,000 个共约 100MB，合理可控。

### 1.2 Pooler 架构

```
        ┌────────────┐
        │  App Pods  │
        └─────┬──────┘
              │ pg-ha-rw.pooler (5432)
              │
     ┌────────┴────────┐
     │  pg-ha-pooler-0 │── 200 PG 后端连接 ──→ pg-ha-rw (Primary)
     │  pg-ha-pooler-1 │── 200 PG 后端连接 ──→ pg-ha-rw (Primary)
     └─────────────────┘
              │ 100 个保留连接（紧急场景）
              │
       ┌──────┴──────┐
       │ pg-ha-svc   │
       │ read-write  │
       └──────┬──────┘
              │
        ┌─────┴─────┐
        │ PostgreSQL│
        │ Primary   │
        └───────────┘
```

---

## 2. PostgreSQL 参数详解

### 2.1 内存参数

| 参数 | CNPG 配置值 | 占 8Gi 比例 | 说明 |
|:----|:----------:|:----------:|:----|
| `shared_buffers` | **2GB** | 25% | PG 共享缓冲池。超过此值反而导致 PG 和 OS 争抢缓存 |
| `effective_cache_size` | **6GB** | 75% | 告诉优化器"可用的 OS 缓存+shared_buffers≈6GB"，不走偏执行计划 |
| `work_mem` | **16MB** | 每个排序/哈希 | 每个查询的排序/哈希操作内存。500 并发排序=8GB，所以不宜过大 |
| `maintenance_work_mem` | **512MB** | 6.25% | VACUUM、ANALYZE、CREATE INDEX 等维护操作可用内存 |
| `wal_buffers` | **16MB** | — | WAL 写入缓冲，防频繁小写 |

### 2.2 存储/SSD 参数

SSD 与 HDD 的物理特性完全不同：

| 参数 | HDD 默认值 | 建议值（SSD） | 原理 |
|:----|:---------:|:-----------:|:------|
| `random_page_cost` | 4.0 | **1.1** | HDD 随机读 ≈ 寻道 10ms；SSD 随机读 ≈ 0.1ms，几乎等同于顺序读 |
| `effective_io_concurrency` | 1 | **200** | SSD 支持高并发队列深度，`1` 等于把 SSD 当单磁头 HDD 用 |
| `wal_compression` | off | **on** | WAL 记录 zstd/lz4 压缩，减少 60-80% WAL I/O |
| `wal_log_hints` | off | **on** | 允许 pg_rewind 修复裂脑，生产必备 |

优化器如何利用这些参数做决策：

```
random_page_cost = 1.1    ← PG 认为随机读几乎和顺序读一样便宜
                   ↓
PG 更倾向于走索引扫描而非顺序扫描
                   ↓
对于覆盖索引的查询 → 准确走索引
对于大范围扫描   → 仍走顺序扫描（正确，因为 1.1 仍略高于 seq_page_cost 1.0）
```

### 2.3 WAL / Checkpoint 参数

| 参数 | 缺省值 | 建议值 | 说明 |
|:----|:-----:|:-----:|:------|
| `min_wal_size` | 80MB | **2GB** | 减少 WAL 翻转频率，避免频繁产生 checkpoint |
| `max_wal_size` | 1GB | **8GB** | checkpoint 间隔放大，减少 I/O 尖峰 |
| `checkpoint_timeout` | 300s | **900s** | 15 分钟一次 checkpoint，预留足够 I/O 窗口 |
| `checkpoint_completion_target` | 0.5 | **0.9** | 把 checkpoint 写入分散到其间隔的 90%，平滑 I/O |

**内存充裕时为什么要增大 WAL 参数？**

每次 checkpoint 产生大量脏页刷盘（`shared_buffers=2GB` 全部脏时可达 2GB）。短间隔会导致：
1. disk write 尖峰（HDD 感明显，SSD 略好但依然存在）
2. 频繁 checkpoint 影响查询响应时间

增大 `max_wal_size` 和 `checkpoint_timeout` 的本质：**用 WAL 空间换 I/O 平滑**。

### 2.4 超时保护参数

| 参数 | 缺省值 | 建议值 | 保护场景 |
|:----|:-----:|:-----:|:--------|
| `statement_timeout` | 0（不限） | **30s** | 防慢 SQL 挂死后端永不释放 |
| `idle_in_transaction_session_timeout` | 0（不限） | **60s** | 防应用开启事务后卡住不动（锁不释放） |
| `idle_session_timeout` | 0（不限） | **300s** | 防死连接占着连接槽位不释放 |
| `tcp_keepalives_idle` | 0（系统默认） | **60s** | 快速检测网络断开，释放后端 |
| `tcp_keepalives_interval` | 0 | **10s** | |
| `tcp_keepalives_count` | 0 | **6** | 总计 60+10×6=120s 确认连接死亡 |

**不设超时的风险**：一个慢查询或悬挂事务可以永远占用连接，最终耗尽 PgBouncer 池。客户端应用崩溃后，PG 后端可能继续运行直到 TCP 超时（默认 2 小时 11 分钟）。

### 2.5 自动清理参数

| 参数 | 缺省值 | 建议值 | 说明 |
|:----|:-----:|:-----:|:------|
| `autovacuum_max_workers` | 3 | **4** | 表多时并行清理 |
| `autovacuum_naptime` | 60s | **30s** | 缩短检查间隔，避免积累大量死元组 |
| `autovacuum_vacuum_scale_factor` | 0.2 | **0.01** | 表 1% 脏即触发，不等 20% |
| `autovacuum_analyze_scale_factor` | 0.1 | **0.005** | 统计信息更新更频繁 |

**为什么需要缩短 autovacuum 周期？**

PostgreSQL MVCC 依赖死元组清理。当 autovacuum 跟不上写入时，表膨胀不可逆：

```text
写入 100万行  → 死元组 100万  → autovacuum 来不及  → 表膨胀到 2GB
                                                      → 全表扫描变慢
                                                      → 索引变大
                                                      → 查询退化
```

缩短周期 + 低阈值 = 高频小批量清理，避免恶性膨胀。

### 2.6 日志 / 审计参数

| 参数 | 缺省值 | 建议值 | 说明 |
|:----|:-----:|:-----:|:------|
| `log_min_duration_statement` | -1（关） | **1000ms** | 记录所有执行超过 1s 的 SQL |
| `log_checkpoints` | off | **on** | 记录 checkpoint 详情（I/O 诊断） |
| `log_connections` | off | **on** | 连接审计 |
| `log_disconnections` | off | **on** | 断连审计（包含持续时间） |
| `log_lock_waits` | off | **on** | 死锁 / 锁等待诊断 |
| `deadlock_timeout` | 1s | **5s** | 死锁检测周期（增大减少误报） |

### 2.7 并行查询参数

| 参数 | 缺省值 | 建议值 | 说明 |
|:----|:-----:|:-----:|:------|
| `max_parallel_workers` | 8 | **8** | 总并行 worker 数上限 |
| `max_parallel_workers_per_gather` | 2 | **4** | 单查询最多并行度 |
| `parallel_tuple_cost` | 0.01 | 保持 | 优化器评估并行代价 |
| `parallel_setup_cost` | 1000 | **100** | 降低 PG 启动并行查询的门槛 |

### 2.8 CNPG 自动管理的参数（无需手动设置）

- `wal_level` — CNPG 自动设为 `logical`（含 replica 的超级）
- `hot_standby` — 自动 `on`
- `max_wal_senders` — CNPG 自动管理（10 起）
- `max_replication_slots` — CNPG 自动设 32
- `hot_standby_feedback` — 自动 `on`

---

## 3. PgBouncer Pooler 配置

### 3.1 Pooler 参数

| 参数 | 值 | 说明 |
|:----|:---:|:------|
| 实例数 | **2** | HA 冗余 |
| `pool_mode` | **transaction** | 事务级复用，最常用模式 |
| `default_pool_size` | **200** | 每个 Pooler 的后端 PG 连接数 |
| `max_client_conn` | **25000** | 每个 Pooler 最大客户端连接 |
| `max_db_connections` | **500** | 数据库级总连接上限 |
| `reserve_pool_size` | **10** | 紧急保留连接 |
| `reserve_pool_timeout` | **5s** | 队列超时后启用保留池 |
| `query_timeout` | **30s** | 查询执行超时 |
| `idle_transaction_timeout` | **60s** | 事务级超时 |
| `server_idle_timeout` | **300s** | 后端连接回收 |

### 3.2 Pooler 资源

| 资源 | Request | Limit |
|:----|:-------:|:-----:|
| CPU | 100m | 500m |
| 内存 | 128Mi | 512Mi |

### 3.3 连接路径

```yaml
# 应用开发连接（通过 Pooler）
pg-ha-rw.pooler.postgres.svc:5432  # 读写
pg-ha-ro.pooler.postgres.svc:5432  # 只读

# 管理调试连接（绕过 Pooler，直连）
pg-ha-rw.postgres.svc:5432         # 读写
pg-ha-ro.postgres.svc:5432         # 只读
```

> 应用通过 Pooler Service 连接（端口 5432 映射到 PgBouncer）。

---

## 4. 资源配置

### 4.1 PostgreSQL 实例

| 资源 | 当前值 | 建议值（Limit） |
|:----|:-----:|:--------------:|
| CPU | 500m | **4000m** |
| 内存 | 512Mi | **8Gi** |

Request 不设置，允许超卖运行（多个工作负载共享集群资源）。

### 4.2 存储

| 数据 | WAL 建议 |
|:----|:--------:|
| 5Gi 独立 WAL 卷 | 独立 PVC 减少 I/O 争抢 |
| StorageClass: `local-path` | |

**WAL 独立卷的好处：**

```text
合卷：data_dir 和 WAL 共享同一 PV
      WAL 写入 → 数据和 WAL 争抢 I/O
      备份读取 → 与 WAL 写入争抢 I/O

分卷：data / WAL 独立 PV
      WAL 持续写入不影响数据读
      checkpoint 刷脏不影响 WAL 写入
```

### 4.3 命名空间配额

| 资源 | 当前值 | 建议值 |
|:----|:-----:|:-----:|
| limits.cpu | 4 | **16** |
| limits.memory | 8Gi | **32Gi** |
| requests.cpu | 2 | **4** |
| requests.memory | 4Gi | **8Gi** |
| PVC | 10 | **15** |

---

## 5. 效果对比

| 维度 | 调优前 | 调优后 |
|:----|:------:|:------:|
| 客户端并发连接 | ~300 | **50,000** |
| PG 后端连接 | 300（直连） | 500（Pooler 复用） |
| 内存利用率 | 512Mi（利用率极低） | **8Gi**（合理分配） |
| SSD 利用率 | random_page_cost=4（当作 HDD） | random_page_cost=1.1（SSD 优化） |
| WAL I/O | 无压缩，高频 checkpoint | zstd 压缩，15min checkpiont |
| 死连接保护 | 无超时 | 多层超时防护 |
| 慢查询日志 | 关闭 | 1s 阈值 + 锁等待 |
| 自动清理 | 默认（20% 脏才触发） | 1% 脏即触发 |
| 连接审计 | 关闭 | 启用电 |

### 5.1 内存分布图（8Gi）

```text
┌─────────────────────────────────────────────┐
│   shared_buffers (2GB)          25%         │
├─────────────────────────────────────────────┤
│   PG 后端连接 500 × ~5MB (2.5GB)  31%      │
├─────────────────────────────────────────────┤
│   OS + 文件缓存 (2GB)           25%         │
├─────────────────────────────────────────────┤
│   work_mem / 临时 / 预留 (1.5GB)  19%      │
└─────────────────────────────────────────────┘
```

---

## 6. 常见问题

### 6.1 为什么 PG max_connections 不设 50000？

PostgreSQL 后端以进程（而非线程）承载连接。每个进程预分配栈 + 私有内存约 5-10MB。50,000 × 5MB = 250GB，远超 8Gi。

解决方案：**PgBouncer 事务连接池**。50,000 个客户端连接在 Pooler 层被复用为约 400 条 PG 后端连接。PgBouncer 本身使用 libevent + 异步 I/O，每个客户端连接仅消耗约 2KB。

### 6.2 为什么不用 HikariCP、Druid 等应用侧连接池？

应用侧连接池和 PgBouncer 解决不同层面的问题：

| 层面 | 工具 | 作用 |
|:----|:----|:-----|
| 应用内 | HikariCP / Druid | 减少应用创建/销毁连接的开销 |
| 数据库前置 | PgBouncer | 集中管理后端连接，防前端洪峰打满 PG |

**两者同时使用效果最佳**：应用侧 HikariCP 维持 10-20 连接 → PgBouncer 复用为 200-400 连接 → PG 500 连接上限。

### 6.3 故障转移后连接池怎么办

CNPG + PgBouncer 自动处理：

1. Primary 宕机 → CNPG 选举新主
2. `pg-ha-rw` Service 切到新主
3. PgBouncer 检测连接断开 → 重建连接到新主
4. 应用通过 Pooler 连接，无需重试逻辑

### 6.4 50,000 客户端需要多少内存？

仅 PgBouncer 层面：50,000 × 2KB ≈ 100MB。整个链路：

| 组件 | 内存 |
|:----|:---:|
| PgBouncer × 2 | 1024Mi（含安全余量） |
| PG 后端 ~400 连接 | ~2-3GB |
| PG shared_buffers | 2GB |
| OS + 文件缓存 | ~2GB |
| **总计** | **约 7-8GB** |
