# 监控方案 — Redis Operator v0.25.0

部署 ServiceMonitor 后 Prometheus 自动采集以下指标。

## 关键指标

| 类别 | 指标 | 说明 |
|------|------|------|
| 存活 | `redis_up` | 1=在线 |
| 内存 | `redis_memory_used_bytes / redis_memory_max_bytes` | 使用率 |
| QPS | `rate(redis_commands_processed_total[1m])` | 每秒命令数 |
| 连接数 | `redis_connected_clients` | 当前连接 |
| 缓存命中率 | `hits / (hits + misses) * 100` | 命中率 |
| 碎片率 | `redis_mem_fragmentation_ratio` | >1.5 需重启 |
| 复制延迟 | `master_repl_offset - slave_repl_offset` | 同步延迟 |
| 集群状态 | `redis_cluster_state` | 1=ok |

## 部署

```bash
kubectl apply -f monitoring/servicemonitor-standalone.yaml
kubectl apply -f monitoring/servicemonitor-cluster.yaml
```

详细告警规则和 Grafana 面板见 [CHECKLIST_MONITORING.md](./CHECKLIST_MONITORING.md)
