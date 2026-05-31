# Redis - 内存缓存/数据库（Operator 方式）

基于 [OT-CONTAINER-KIT/redis-operator](https://github.com/OT-CONTAINER-KIT/redis-operator) 部署，
支持 standalone / sentinel HA / cluster 三种模式切换。

## 部署架构

```
┌────────────────────────────────────────────┐
│  Namespace: redis-operator                 │
│  ┌──────────────────────────────────────┐  │
│  │  Pod: redis-operator (controller)    │  │
│  └──────────────┬───────────────────────┘  │
└─────────────────┼──────────────────────────┘
                  │ 管理 CR
┌─────────────────▼──────────────────────────┐
│  Namespace: redis                           │
│  ┌──────────────────────────────────────┐  │
│  │  CR: Redis/redis-standalone          │  │
│  │  ├── StatefulSet: redis-standalone   │  │
│  │  │   └── redis:7.2-alpine           │  │
│  │  ├── Service: redis-standalone       │  │
│  │  │   └── ClusterIP:6379             │  │
│  │  ├── Service: redis-external        │  │
│  │  │   └── NodePort:30003             │  │
│  │  └── PVC: redis-standalone (1Gi)    │  │
│  └──────────────────────────────────────┘  │
└────────────────────────────────────────────┘
```

- **operator**: `quay.io/opstree/redis-operator:v0.24.0`
- **Redis 镜像**: `quay.io/opstree/redis:v7.0.15`
  - 必须使用 operator 定制镜像（负责密码注入、配置合并等 hook）
  - v7.0.x 仍为 BSD 开源协议（v7.4+ 改为 SSPL/RSAL）
- **持久化**: 1Gi PVC (local-path)
- **认证**: Secret 注入密码 `redis@czw`
- **端口**: 6379(ClusterIP) + 30003(NodePort)

## 快速开始

```bash
# 安装（先装 operator，再创建 Redis 实例）
./install.sh

# 卸载
./uninstall.sh
```

## 验收确认

```bash
# 查看 operator Pod
kubectl get pods -n redis-operator
# 期望输出：redis-operator-xxxxx   1/1   Running

# 查看 Redis 实例 Pod
kubectl get pods -n redis
# 期望输出：redis-standalone-0   1/1   Running

# 查看 CR
kubectl get redis -n redis
# 期望输出：redis-standalone   reconciled

# 查看 Service
kubectl get svc -n redis
# redis-standalone   ClusterIP   6379/TCP
# redis-external     NodePort    6379:30003/TCP

# 查看 PVC
kubectl get pvc -n redis
# redis-standalone   Bound   1Gi   RWO   local-path
```

### 连接测试

```bash
# 集群外
redis-cli -h 192.168.5.249 -p 30003 -a 'redis@czw' ping
# 期望输出：PONG

# 集群内
kubectl exec -n redis deploy/redis-standalone -- redis-cli -a 'redis@czw' ping
# 期望输出：PONG
```

### 访问地址

| 方式 | 地址 |
|------|------|
| NodePort | `<节点IP>:30003` |
| 集群内 DNS | `redis-standalone.redis.svc.cluster.local:6379` |
| 密码 | `redis@czw` |

## 切换其他模式

operator 支持多种模式，operator/ 目录中已预置 standalone CR。
如需切换为 sentinel 或 cluster，创建对应的 CR 即可：

```bash
# Sentinel HA 模式（参考 operator 官方示例）
kubectl apply -f sentinel-cr.yaml

# Cluster 模式
kubectl apply -f cluster-cr.yaml
```

参考：https://github.com/OT-CONTAINER-KIT/redis-operator/tree/main/example/v1beta2

## 卸载

```bash
./uninstall.sh
```

## 注意

- 默认密码 `redis@czw`，部署后请修改
- 修改密码后需重启 Pod 生效
- operator 安装在 `redis-operator` 命名空间，Redis 数据实例在 `redis` 命名空间
