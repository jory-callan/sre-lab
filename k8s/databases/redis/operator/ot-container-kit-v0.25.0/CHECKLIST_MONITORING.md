# 监控指标与告警配置清单

## 一、Prometheus 告警规则

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
  - name: redis-critical
    interval: 30s
    rules:
    # P0 — Redis 宕机
    - alert: RedisDown
      expr: redis_up == 0
      for: 30s
      labels: { severity: critical, team: sre }
      annotations:
        summary: "Redis {{ $labels.instance }} DOWN"
        description: "Pod {{ $labels.kubernetes_pod_name }} 离线 30s"

    # P0 — 集群故障
    - alert: RedisClusterDown
      expr: redis_cluster_state == 0
      for: 10s
      labels: { severity: critical, team: sre }
      annotations:
        summary: "Redis Cluster {{ $labels.instance }} FAIL"
        description: "部分 slot 不可用"

    # P0 — 无从节点
    - alert: RedisNoSlaves
      expr: redis_connected_slaves{role="master"} == 0
      for: 30s
      labels: { severity: critical }
      annotations:
        summary: "主节点 {{ $labels.instance }} 无从"

    # P1 — 内存 > 80%
    - alert: RedisMemoryHigh
      expr: redis_memory_used_bytes / redis_memory_max_bytes * 100 > 80
      for: 5m
      labels: { severity: warning }
      annotations:
        summary: "Redis {{ $labels.instance }} 内存 > 80%"
        description: "当前 {{ $value | humanizePercentage }}"

    # P1 — OOM 风险
    - alert: RedisOOMRisk
      expr: redis_memory_used_bytes / redis_memory_max_bytes * 100 > 95
      for: 1m
      labels: { severity: warning }
      annotations:
        summary: "Redis {{ $labels.instance }} 内存 > 95%"
        description: "即将 OOM Kill"

    # P1 — 复制延迟
    - alert: RedisReplicationLag
      expr: redis_master_repl_offset - on(instance) redis_slave_repl_offset > 1048576
      for: 1m
      labels: { severity: warning }
      annotations:
        summary: "Redis {{ $labels.instance }} 同步延迟 > 1MB"
        description: "检查网络带宽"

    # P1 — 碎片率高
    - alert: RedisFragmentation
      expr: redis_mem_fragmentation_ratio > 1.5
      for: 15m
      labels: { severity: info }
      annotations:
        summary: "Redis {{ $labels.instance }} 碎片率 {{ $value }}"
        description: "重启可释放"

    # P2 — 无备份
    - alert: RedisNoBackup
      expr: time() - redis_rdb_last_save_timestamp_seconds > 86400
      for: 1h
      labels: { severity: info }
      annotations:
        summary: "Redis {{ $labels.instance }} 24h 未备份"

    # P2 — 驱逐 Key
    - alert: RedisEvictions
      expr: rate(redis_evicted_keys_total[5m]) > 0
      for: 5m
      labels: { severity: info }
      annotations:
        summary: "Redis {{ $labels.instance }} 正在驱逐 Key"
        description: "速率 {{ $value }} keys/s"
```

## 二、Grafana 面板

| ID | 名称 |
|----|------|
| 11835 | Redis Dashboard for Prometheus Redis Exporter |
| 763 | Redis |

## 三、巡检命令

```bash
# 存活
kubectl exec redis-standalone-0 -c redis -- redis-cli ping

# 内存
kubectl exec redis-standalone-0 -c redis -- redis-cli info memory | grep -E 'used_memory|maxmemory|fragmentation'

# 复制
kubectl exec redis-cluster-leader-0 -c redis -- redis-cli info replication | grep -E 'role|connected_slaves|offset'

# 集群
kubectl exec redis-cluster-leader-0 -c redis -- redis-cli cluster info | grep -E 'cluster_state|slots_ok'
```
