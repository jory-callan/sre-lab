# Redis - 内存缓存/数据库

单实例 Redis 7，带 AOF+RDB 持久化，适用于缓存和轻量数据存储。

## 部署架构

```
客户端 (redis-cli 或应用)
    │
    ├── :30003 (NodePort)
    │
    ▼
┌──────────────────────┐
│  Service: redis      │
│  NodePort:30003      │
└──────┬───────────────┘
       ▼
┌──────────────────────┐
│  Pod: redis:7-alpine │
│  密码认证            │
└──────┬───────────────┘
       ▼
┌──────────────────────┐
│  PVC: redis-data     │
│  1Gi local-path      │
│  /data (AOF+RDB)     │
└──────────────────────┘
```

- **镜像**: `redis:7-alpine`（约 12MB，通过 docker.xuanyuan.me 代理拉取）
- **持久化**: AOF + RDB 双启，1Gi PVC (local-path)
- **认证**: Secret 注入密码 `redis@czw`
- **端口**: 6379(容器) → 30003(NodePort)

## 快速开始

```bash
# 安装
./install.sh

# 卸载
./uninstall.sh
```

## 验收确认

```bash
# 查看 Pod
kubectl get pods -n redis
# 期望输出：redis-xxxxx-xxxxx   1/1   Running

# 查看 Service
kubectl get svc -n redis
# 期望输出：redis   NodePort   10.43.xx.xx   6379:30003/TCP

# 查看 PVC
kubectl get pvc -n redis
# 期望输出：redis-data   Bound   1Gi   RWO   local-path
```

### 连接测试

```bash
# 集群外（任一节点 IP）
redis-cli -h 192.168.5.249 -p 30003 -a 'redis@czw' ping
# 期望输出：PONG

# 集群内
kubectl exec -n redis deploy/redis -- redis-cli -a 'redis@czw' ping
# 期望输出：PONG
```

### 访问地址

| 方式 | 地址 |
|------|------|
| NodePort | `<节点IP>:30003` |
| 集群内 DNS | `redis.redis.svc.cluster.local:6379` |
| 密码 | `redis@czw` |

## 卸载

```bash
./uninstall.sh
```

## 注意

- 单副本部署，重启时有短暂中断
- 默认密码 `redis@czw`，部署后请修改
