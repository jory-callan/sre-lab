# Redis Operator 安装

## 方式一：Helm（推荐）

```bash
helm repo add ot-container https://ot-container.github.io/helm-charts/
helm repo update

# CRD 较大，建议先手动安装，或用 --include-crds
kubectl apply --server-side \
  -f https://raw.githubusercontent.com/OT-CONTAINER-KIT/redis-operator/v0.25.0/config/crd/bases/redis.redis.opstreelabs.in_redisses.yaml \
  -f https://raw.githubusercontent.com/OT-CONTAINER-KIT/redis-operator/v0.25.0/config/crd/bases/redis.redis.opstreelabs.in_redisreplications.yaml \
  -f https://raw.githubusercontent.com/OT-CONTAINER-KIT/redis-operator/v0.25.0/config/crd/bases/redis.redis.opstreelabs.in_redissentinels.yaml \
  -f https://raw.githubusercontent.com/OT-CONTAINER-KIT/redis-operator/v0.25.0/config/crd/bases/redis.redis.opstreelabs.in_redisclusters.yaml

# 安装 Operator
helm upgrade --install redis-operator ot-container/redis-operator \
  --namespace redis-operator \
  --create-namespace \
  --version 0.25.0
```

## 方式二：Kustomize + ArgoCD

见 `operators/redis-operator/`（生产使用的方式）

## 验证 Operator 就绪

```bash
kubectl -n redis-operator get pod -l app.kubernetes.io/name=redis-operator
kubectl -n redis-operator logs -l app.kubernetes.io/name=redis-operator
kubectl get crd | grep redis.opstreelabs
```

## CRD 列表

| CRD | 用途 |
|-----|------|
| `redises.redis.redis.opstreelabs.in` | 单机 Redis |
| `redisreplications.redis.redis.opstreelabs.in` | 主从复制（当前使用）|
| `redissentinels.redis.redis.opstreelabs.in` | Sentinel 哨兵（当前使用）|
| `redisclusters.redis.redis.opstreelabs.in` | 分片集群 |

## 版本说明

当前验证：**Operator v0.25.0 / Redis 7.0.15**

Operator 更新频率不高，但足够稳定。镜像源在 quay.io，无 docker.io 限速。
