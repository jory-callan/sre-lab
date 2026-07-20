# Redis — 测试实例

KubeBlocks 管理的 Redis replication 集群，含 Sentinel 高可用。

## 版本

| 组件 | 版本 |
|------|------|
| Redis | 7.2.4 |
| 拓扑 | replication |
| Sentinel | 3 副本 |

## 访问

```bash
# 主节点
kubectl -n redis get svc redis-redis

# 从节点
kubectl -n redis get svc redis-redis -o jsonpath='{.metadata.name}'

# 哨兵
kubectl -n redis get svc redis-redis-sentinel
```

## 验证

```bash
kubectl -n redis get pods -l app.kubernetes.io/instance=redis
kubectl -n redis get cluster redis
```
