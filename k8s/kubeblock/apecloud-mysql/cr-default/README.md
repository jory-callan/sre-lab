# ApeCloud MySQL — 测试实例

KubeBlocks 管理的 ApeCloud MySQL 集群，Raft 协议高可用。

## 版本

| 组件 | 版本 |
|------|------|
| ApeCloud MySQL | 8.0.30 |
| 拓扑 | apecloud-mysql |
| 副本数 | 3 |

## 访问

```bash
kubectl -n mysql get svc apecloud-mysql-mysql
```

## 验证

```bash
kubectl -n mysql get pods -l app.kubernetes.io/instance=apecloud-mysql
kubectl -n mysql get cluster apecloud-mysql
```
