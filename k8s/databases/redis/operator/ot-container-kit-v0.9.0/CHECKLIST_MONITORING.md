# Redis 监控指标与告警配置清单

> 本清单适用于 OT-Container-KIT/redis-operator v0.9.0 + Prometheus + Grafana。
> 完整方案见 [GUIDE_MONITORING.md](./GUIDE_MONITORING.md)

---

## 一、指标采集清单

部署 ServiceMonitor 后 Prometheus 自动采集以下指标：

### 1.1 存活与基础

| 指标名 | 类型 | 维度 | 说明 |
|--------|------|------|------|
| `redis_up` | Gauge | instance | 1=在线 0=离线 |
| `redis_instance_info` | Gauge | version,role,os | 实例元数据 |
| `redis_exporter_last_scrape_error` | Gauge | — | 0=正常 >0=采集异常 |
| `redis_uptime_in_seconds` | Counter | — | 运行时长 |
| `redis_config_maxmemory` | Gauge | — | 配置的 maxmemory |

### 1.2 性能

| 指标名 | 类型 | 说明 |
|--------|------|------|
| `redis_cpu_sys_seconds_total` | Counter | 内核态 CPU 累计 |
| `redis_cpu_user_seconds_total` | Counter | 用户态 CPU 累计 |
| `redis_memory_used_bytes` | Gauge | 已用内存 |
| `redis_memory_max_bytes` | Gauge | 最大内存（= maxmemory） |
| `redis_mem_fragmentation_ratio` | Gauge | 内存碎片率 |
| `redis_connected_clients` | Gauge | 当前连接数 |
| `redis_commands_processed_total` | Counter | 累计处理命令数 |
| `redis_keyspace_hits_total` | Counter | 缓存命中次数 |
| `redis_keyspace_misses_total` | Counter | 缓存未命中次数 |
| `redis_expired_keys_total` | Counter | 已过期 Key 数 |
| `redis_evicted_keys_total` | Counter | 已驱逐 Key 数 |

### 1.3 持久化

| 指标名 | 类型 | 说明 |
|--------|------|------|
| `redis_rdb_last_save_timestamp_seconds` | Gauge | 上次 RDB 保存时间戳 |
| `redis_rdb_bgsave_in_progress` | Gauge | RDB 是否正在执行（0/1）|
| `redis_rdb_changes_since_last_save` | Gauge | RDB 之后变更的 Key 数 |
| `redis_aof_enabled` | Gauge | AOF 是否开启（0/1）|
| `redis_aof_rewrite_in_progress` | Gauge | AOF 重写是否进行中 |

### 1.4 复制（主从/集群）

| 指标名 | 类型 | 说明 |
|--------|------|------|
| `redis_connected_slaves` | Gauge | 从节点连接数 |
| `redis_master_repl_offset` | Counter | 主节点复制偏移量 |
| `redis_slave_repl_offset` | Counter | 从节点复制偏移量 |
| `redis_slave_info{state="online"}` | Gauge | 从节点在线状态 |
| `redis_repl_backlog_size` | Gauge | 复制积压缓冲区大小 |
| `redis_repl_backlog_active` | Gauge | 复制积压缓冲区是否激活 |

### 1.5 集群（仅 Cluster 模式）

| 指标名 | 类型 | 说明 |
|--------|------|------|
| `redis_cluster_state` | Gauge | 1=ok 0=fail |
| `redis_cluster_slots_ok` | Gauge | 正常 slot 数（=16384 为正常）|
| `redis_cluster_slots_fail` | Gauge | 故障 slot 数 |
| `redis_cluster_known_nodes` | Gauge | 已知节点总数 |
| `redis_cluster_size` | Gauge | 分片数 |
| `clusterNodeRole{role="master"}` | Gauge | 标记 master 节点 |

---

## 二、Prometheus 告警规则

### 2.1 故障告警（P0 — 立即响应）

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: redis-alerts
  namespace: redis-operator
  labels:
    release: prometheus           # 与你的 Prometheus release 一致
spec:
  groups:
  - name: redis-critical
    interval: 30s
    rules:
    - alert: RedisDown
      expr: redis_up == 0
      for: 30s
      labels:
        severity: critical
        team: sre
      annotations:
        summary: "Redis 实例 {{ $labels.instance }} 宕机"
        description: "Pod {{ $labels.kubernetes_pod_name }} 已离线超过 30s"
        runbook: "kubectl -n {{ $labels.namespace }} get pod -l app={{ $labels.kubernetes_pod_name | regexFind \"redis-.*\" }}"

    - alert: RedisClusterDown
      expr: redis_cluster_state == 0
      for: 10s
      labels:
        severity: critical
        team: sre
      annotations:
        summary: "Redis Cluster {{ $labels.instance }} 集群状态异常"
        description: "cluster_state=fail，部分 slot 不可用"
        runbook: "kubectl exec {{ $labels.kubernetes_pod_name }} -c redis -- redis-cli cluster info"

    - alert: RedisNoSlaves
      expr: redis_connected_slaves{role="master"} == 0
      for: 30s
      labels:
        severity: critical
      annotations:
        summary: "Redis 主节点 {{ $labels.instance }} 没有从节点"
        description: "该主节点复制拓扑异常，故障时无法自动切换"
```

### 2.2 性能告警（P1 — 工作时间内响应）

```yaml
  - name: redis-performance
    interval: 60s
    rules:
    - alert: RedisMemoryHigh
      expr: redis_memory_used_bytes / redis_memory_max_bytes * 100 > 80
      for: 5m
      labels:
        severity: warning
        team: sre
      annotations:
        summary: "Redis {{ $labels.instance }} 内存使用率 > 80%"
        description: "当前 {{ $value | humanizePercentage }}，需扩容或排查内存泄漏"

    - alert: RedisMemoryOOMRisk
      expr: redis_memory_used_bytes / redis_memory_max_bytes * 100 > 95
      for: 1m
      labels:
        severity: warning
      annotations:
        summary: "Redis {{ $labels.instance }} 内存使用率 > 95%，OOM 风险极高"
        description: "接近 maxmemory，即将触发逐出策略或 OOM Kill"

    - alert: RedisReplicationLag
      expr: redis_master_repl_offset - on(instance) redis_slave_repl_offset > 1024 * 1024
      for: 1m
      labels:
        severity: warning
      annotations:
        summary: "Redis {{ $labels.instance }} 主从同步延迟 > 1MB"
        description: "复制积压增加，可能网络带宽不足"

    - alert: RedisFragmentationHigh
      expr: redis_mem_fragmentation_ratio > 1.5
      for: 15m
      labels:
        severity: warning
      annotations:
        summary: "Redis {{ $labels.instance }} 内存碎片率 {{ $value | humanize }}"
        description: "碎片率 > 1.5 持续 15 分钟，建议重启"
        runbook: "kubectl delete pod {{ $labels.kubernetes_pod_name }}"

    - alert: RedisHitRateLow
      expr: rate(redis_keyspace_hits_total[5m]) / (rate(redis_keyspace_hits_total[5m]) + rate(redis_keyspace_misses_total[5m])) * 100 < 80
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "Redis {{ $labels.instance }} 缓存命中率 {{ $value | humanize }}%"
        description: "命中率 < 80%，大量请求落到后端存储"
```

### 2.3 持久化与容量告警（P2 — 记录并跟进）

```yaml
  - name: redis-maintenance
    interval: 5m
    rules:
    - alert: RedisNoBackup
      expr: time() - redis_rdb_last_save_timestamp_seconds > 86400
      for: 1h
      labels:
        severity: info
      annotations:
        summary: "Redis {{ $labels.instance }} 超过 24h 未 RDB 备份"
        description: "上次备份: {{ $value | humanizeDuration }} 前"

    - alert: RedisEvictions
      expr: rate(redis_evicted_keys_total[5m]) > 0
      for: 5m
      labels:
        severity: info
      annotations:
        summary: "Redis {{ $labels.instance }} 正在驱逐 Key"
        description: "速率 {{ $value | humanize }} keys/s，maxmemory 可能太小"

    - alert: RedisConnectionsSurge
      expr: redis_connected_clients > 2000
      for: 5m
      labels:
        severity: info
      annotations:
        summary: "Redis {{ $labels.instance }} 连接数 > 2000"
        description: "可能连接泄漏或突发流量"
```

### 2.4 部署告警规则

```bash
# 将上述规则保存为 redis-alerts.yaml
# 修改 release label 与你的 Prometheus 一致
kubectl apply -f redis-alerts.yaml

# 确认规则已加载
# Prometheus UI → Status → Rules → redis-alerts 应可见
```

---

## 三、Grafana 面板清单

### 3.1 核心面板

| 面板 | 数据源 | 可视化类型 | 位置 |
|------|--------|-----------|------|
| Redis 存活 | `redis_up` | Stat（绿/红） | 顶部 Row |
| 内存使用率 | `redis_memory_used / redis_memory_max * 100` | Time Series + Gauge | 第一行 |
| QPS | `rate(redis_commands_processed_total[1m])` | Time Series | 第一行 |
| 连接数 | `redis_connected_clients` | Time Series | 第一行 |
| 缓存命中率 | `ratio(hits / (hits + misses))` | Gauge % | 第二行 |
| 碎片率 | `redis_mem_fragmentation_ratio` | Time Series | 第二行 |
| CPU 使用率 | `rate(redis_cpu_sys_total[1m]) + rate(redis_cpu_user[1m])` | Time Series | 第二行 |
| 网络 IO | `rate(redis_net_input_bytes_total[1m])` | Time Series | 第二行 |
| Key 统计 | `redis_db_keys` | Stat | 第三行 |
| 过期 vs 驱逐 | `rate(redis_expired_keys_total[1m])` vs `rate(redis_evicted_keys_total[1m])` | Time Series | 第三行 |
| 复制延迟 | `redis_master_repl_offset - redis_slave_repl_offset` | Time Series | 第三行 |
| 集群 Slot 分布 | `redis_cluster_slots_ok` | Stat | 第三行 |

### 3.2 推荐的 Grafana 社区面板

| 面板 ID | 名称 | 说明 |
|---------|------|------|
| [11835](https://grafana.com/grafana/dashboards/11835) | Redis Dashboard for Prometheus Redis Exporter | 社区最流行的 Redis 面板 |
| [12776](https://grafana.com/grafana/dashboards/12776) | Redis Sentinel | Sentinel 专用 |
| 763 | Redis | 轻量级面板 |

导入方式：Grafana → + → Import → 输入 Dashboard ID → Load → 选择 Prometheus 数据源。

---

## 四、健康检查清单（kubectl 手动巡检）

```bash
# 存活
kubectl get pods -l app=redis-standalone
kubectl exec redis-standalone-0 -c redis -- redis-cli ping              # → PONG

# 内存
kubectl exec redis-standalone-0 -c redis -- redis-cli info memory \
  | grep -E 'used_memory_human|used_memory_rss_human|maxmemory_human|mem_fragmentation_ratio'

# 复制（主节点上执行）
kubectl exec redis-cluster-leader-0 -c redis -- redis-cli info replication \
  | grep -E 'role|connected_slaves|master_repl_offset|slave_repl_offset'

# 集群
kubectl exec redis-cluster-leader-0 -c redis -- redis-cli cluster info \
  | grep -E 'cluster_state|cluster_slots_ok|cluster_known_nodes'

# Key 数量
kubectl exec redis-standalone-0 -c redis -- redis-cli info keyspace

# 持久化
kubectl exec redis-standalone-0 -c redis -- redis-cli info persistence \
  | grep -E 'rdb_last_save_time|aof_enabled|aof_last_rewrite_time_sec'

# exporter 指标可用
kubectl exec redis-standalone-0 -c redis-exporter -- wget -qO- http://localhost:9121/metrics 2>/dev/null | head -3
```

---

## 五、故障响应矩阵

| 告警 | 影响 | 响应动作 |
|------|------|---------|
| RedisDown | 业务不可用 | `kubectl describe pod` 查原因 → 看事件/Kill 还是 OOM |
| ClusterDown | 部分 slot 不可写 | `redis-cli cluster nodes` 看失败节点 → 重启 |
| Memory > 95% | 触发 eviction/oom | 垂直扩容（改 CR resources）→ `kubectl delete pod` 触发新配置 |
| 碎片率 > 1.5 | 内存浪费 50%+ | `kubectl delete pod`（重启后碎片自动释放）|
| 复制延迟 | 故障切换丢数据 | 检查网络带宽 → 考虑增大 repl-backlog |
| 无备份 > 24h | 数据丢失风险 | 检查 CronJob 是否运行 → `kubectl logs job/redis-backup-xxx` |
