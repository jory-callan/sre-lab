# Valkey — 测试实例

KubeBlocks 管理的 Valkey replication-8 集群，含 Sentinel 高可用。

## 版本

| 组件 | 版本 |
|------|------|
| Valkey | 8.1.8 |
| 拓扑 | replication-8 |
| Sentinel | 3 副本 |

## 访问

```bash
# 主节点
kubectl -n valkey get svc valkey-valkey

# 哨兵
kubectl -n valkey get svc valkey-valkey-sentinel
```

## 验证

```bash
kubectl -n valkey get pods -l app.kubernetes.io/instance=valkey
kubectl -n valkey get cluster valkey
```
