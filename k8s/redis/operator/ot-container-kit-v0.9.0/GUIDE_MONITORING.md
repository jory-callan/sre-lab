# 监控方案 — Redis Operator v0.9.0

> 完整的 Redis 生产监控 — 指标采集 → Prometheus → Grafana → 告警规则

## 架构

```
┌────────────────────┐    ┌──────────────┐    ┌───────────────┐
│  Redis Pod          │    │  Prometheus   │    │  Grafana       │
│                     │    │              │    │               │
│  ┌───────┐          │    │  ┌────────┐  │    │  ┌───────────┐│
│  │redis  │:6379     │    │  │TSDB    │  │    │  │Dashboard  ││
│  │       ├───┐      │    │  └────────┘  │    │  └───────────┘│
│  └───────┘   │      │    │              │    │               │
│  ┌───────────┘      │    │  ┌────────┐  │    │  ┌───────────┐│
│  │redis-exporter    │    │  │Rules/  │  │    │  │Alertmanager│
│  │:9121    ─────────┼───→│  │Alerts  │  │    │  │            │
│  └──────────────────┘    │  └────────┘  │    │  └───────────┘│
└────────────────────┘    └──────────────┘    └───────────────┘
```

## 组件清单

| 组件 | 端口 | 路径 | 说明 |
|------|------|------|------|
| redis | 6379 | — | Redis 本身 |
| redis-exporter | 9121 | `/metrics` | Prometheus 指标端点 |
| ServiceMonitor | — | — | Prometheus Operator 自动发现 |

## 部署步骤

### 前提：Prometheus Operator

确保集群已部署 kube-prometheus-stack：

```bash
kubectl get crd servicemonitors.monitoring.coreos.com
# servicemonitors.monitoring.coreos.com   2024-xx-xx
```

### 1. 创建 ServiceMonitor

```bash
# 单机监控
kubectl apply -f monitoring/servicemonitor-standalone.yaml

# 集群监控
kubectl apply -f monitoring/servicemonitor-cluster.yaml
```

### 2. 确认指标已接入

```bash
# 在 Prometheus UI → Status → Targets 中应看到
# redis-standalone-monitor/0 (1/1 up)
# redis-cluster-monitor/0 (3/3 up)
```

## 关键指标详解

### 可用性指标

| PromQL | 含义 | 告警阈值 |
|--------|------|---------|
| `redis_up{service="redis-standalone"}` | Redis 是否在线 | `== 0` → ❌ P1 |
| `redis_instance_info` | 实例元数据（版本/角色） | 信息参考 |
| `redis_exporter_last_scrape_error` | Exporter 采集错误 | `> 0` → ⚠️ P2 |

### 性能指标

| PromQL | 含义 | 正常范围 | 告警 |
|--------|------|---------|------|
| `rate(redis_cpu_sys_seconds_total[1m]) + rate(redis_cpu_user_seconds_total[1m])` | CPU 使用率 | <80% | >80% |
| `redis_memory_used_bytes / redis_memory_max_bytes * 100` | 内存使用率 | <80% | >80% → ⚠️ |
| `rate(redis_commands_processed_total[1m])` | QPS | 视业务 | 突降 → 检查 |
| `redis_connected_clients` | 当前连接数 | 视业务 | 突增/突降 |
| `redis_mem_fragmentation_ratio` | 内存碎片率 | 1~1.5 | >1.5 → 需重启 |

### 持久化指标

| PromQL | 含义 | 告警 |
|--------|------|------|
| `redis_rdb_last_save_timestamp_seconds - time()` | RDB 上次保存距今 | >3600s → ⚠️ |
| `redis_rdb_bgsave_in_progress` | RDB 正在执行 | >300s → ⚠️ |
| `redis_aof_last_rewrite_time_sec` | AOF 重写耗时 | >60s → ⚠️ |

### 复制指标（主从/集群）

| PromQL | 含义 | 告警 |
|--------|------|------|
| `redis_connected_slaves` | 从节点数量 | 与预期不一致 → ⚠️ |
| `redis_master_repl_offset - redis_slave_repl_offset` | 复制延迟字节数 | 持续增长 → ⚠️ |
| `redis_slave_info{state="online"}` | 从节点在线状态 | `== 0` → ❌ |

### 集群专属指标

| PromQL | 含义 | 告警 |
|--------|------|------|
| `redis_cluster_state` | 集群状态 | `== 0` → ❌ P0 |
| `redis_cluster_slots_ok` | 正常 slot 数 | `< 16384` → ❌ P0 |
| `redis_cluster_known_nodes` | 已知节点数 | 与预期不一致 → ⚠️ |
| `clusterNodeRole{role="master"}` | 角色分布 | 确保 master 数量正确 |

## 告警规则（推荐）

创建 `prometheus-alerts.yaml`：

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: redis-alerts
  namespace: redis-operator
  labels:
    release: prometheus
spec:
  groups:
  - name: redis
    rules:
    # P0 — Redis 挂了 → 立即响应
    - alert: RedisDown
      expr: redis_up == 0
      for: 30s
      labels:
        severity: critical
        pager: p0
      annotations:
        summary: "Redis {{ $labels.instance }} is down"
        description: "Redis instance {{ $labels.instance }} has been unreachable for 30s"

    # P0 — 集群状态异常
    - alert: RedisClusterDown
      expr: redis_cluster_state == 0
      for: 10s
      labels:
        severity: critical
        pager: p0
      annotations:
        summary: "Redis Cluster {{ $labels.instance }} is DOWN"

    # P1 — 内存超 80%
    - alert: RedisMemoryHigh
      expr: redis_memory_used_bytes / redis_memory_max_bytes * 100 > 80
      for: 5m
      labels:
        severity: warning
        pager: p1
      annotations:
        summary: "Redis {{ $labels.instance }} memory > 80%"

    # P1 — 复制延迟
    - alert: RedisReplicationLag
      expr: redis_master_repl_offset - redis_slave_repl_offset > 1024
      for: 1m
      labels:
        severity: warning
        pager: p1
      annotations:
        summary: "Redis replication lag on {{ $labels.instance }}"

    # P2 — 连接数暴增（可能内存泄露）
    - alert: RedisConnectionsSurge
      expr: redis_connected_clients > 1000
      for: 5m
      labels:
        severity: info
        pager: p2
      annotations:
        summary: "Redis {{ $labels.instance }} has >1000 connections"

    # P2 — 无备份告警
    - alert: RedisNoBackup
      expr: time() - redis_rdb_last_save_timestamp_seconds > 86400
      for: 1h
      labels:
        severity: warning
      annotations:
        summary: "Redis {{ $labels.instance }} last RDB save > 24h ago"
```

部署告警规则：

```bash
kubectl apply -f prometheus-alerts.yaml
```

## Grafana Dashboard

### 导入方式

原项目 v0.9.0 提供了 Grafana Dashboard JSON：

```bash
# 从 v0.9.0 源码获取
cat /Users/czw/code/redis-operator/dashboards/redis-operator-cluster.json
```

在 Grafana → **+** → **Import** → 粘贴 JSON → 选择 Prometheus 数据源。

### 推荐面板清单

如果从头建，建议包含以下面板：

```
Row: Overview
  ├─ Redis Uptime / Aliveness         — Stat / 绿/红
  ├─ Connected Clients                 — Time Series
  ├─ Commands Processed (QPS)          — Time Series
  └─ Memory Usage                      — Time Series（used vs max）

Row: Resource
  ├─ CPU Usage                         — Time Series
  ├─ Memory Fragmentation Ratio        — Time Series
  ├─ Hit Ratio (keyspace_hits / total) — Gauge / %
  └─ Network IO (input/output)         — Time Series

Row: Persistence
  ├─ Last RDB Save                     — Stat
  ├─ RDB Changes Since Last Save       — Stat
  └─ AOF Rewrite Status                — Stat

Row: Cluster（仅集群模式）
  ├─ Cluster State                     — Stat
  ├─ Slots per Node                    — Table / Pie
  ├─ Nodes per Role                    — Table
  └─ Replication Lag per Replica       — Time Series
```

## 常见问题

### Q: 看不到 metrics？

```bash
# 检查 exporter 是否正常运行
kubectl exec -it redis-standalone-0 -c redis-exporter -- wget -qO- http://localhost:9121/metrics | head

# 检查 Service 端口
kubectl get svc redis-standalone -o jsonpath='{.spec.ports}'
# 应包含 { "name": "redis-exporter", "port": 9121 }

# 检查 Service 是否有 redis_setup_type label
kubectl get svc redis-standalone --show-labels
# 应包含 redis_setup_type=standalone（否则 ServiceMonitor 匹配不上）
```

### Q: 为什么 exporter 容器没有 ports 声明？

v0.9.0 已知缺陷，exporter 容器定义中没有 `Ports` 字段。但 ServiceMonitor 是通过 **Service 端口** 来发现 target，不是 Pod 端口。只要 Service 里有 9121 端口（operator 会自动创建），ServieMonitor 就能正常抓取。

如果抓取失败，检查 Service 定义：

```bash
kubectl describe svc redis-standalone | grep -A5 "9121"
```

### Q: 内存碎片率高怎么办？

```bash
# 查看碎片率
kubectl exec redis-standalone-0 -c redis -- redis-cli info memory | grep mem_fragmentation_ratio

# 碎片率 > 1.5，需要重启（重启后自动释放）
kubectl delete pod redis-standalone-0
```

## 参考

- [redis_exporter GitHub](https://github.com/oliver006/redis_exporter)
- [Prometheus RED方法](https://grafana.com/blog/2018/08/02/the-red-method-how-to-instrument-your-services/)
