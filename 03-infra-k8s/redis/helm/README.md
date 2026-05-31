# Helm Chart: redis-operator

## 来源

- **Chart**: redis-operator 0.24.0
- **远程仓库**: `https://github.com/OT-CONTAINER-KIT/redis-operator`
- **下载方式**:
  ```bash
  # 从 GitHub Release 下载
  curl -sL https://github.com/OT-CONTAINER-KIT/redis-operator/archive/refs/tags/v0.25.0.tar.gz
  # 解压后 charts/redis-operator/ 即为离线 chart
  ```
- **离线路径**: `remote-redis-operator-0.24.0/`（禁止修改此目录）

## 本地安装

```bash
# 1. 安装 operator（包含 CRDs）
helm upgrade --install redis-operator ./remote-redis-operator-0.24.0 \
  -n redis-operator --create-namespace \
  -f ./values-prod.yaml

# 2. 创建 Redis 实例 CR
kubectl apply -f ../operator/
```

## 目录说明

| 文件/目录 | 说明 |
|-----------|------|
| `remote-redis-operator-0.24.0/` | 离线 Chart 文件，禁止修改 |
| `values-prod.yaml` | 生产环境配置覆盖（资源限制、副本数等） |

## 关键配置

| 配置项 | values-prod.yaml 值 | 说明 |
|--------|---------------------|------|
| `redisOperator.resources` | 100m/128Mi → 300m/256Mi | operator 资源限制 |
| `redisOperator.replicas` | 1 | 单副本 |
| `redisOperator.webhook` | false | 不启用 webhook（无需 cert-manager） |

Redis 实例配置见 `../operator/` 目录中的 CR YAML。

## 支持的 Redis 模式

| CRD | 说明 | 文件 |
|-----|------|------|
| `Redis` | 单实例 standalone | `operator/01-redis-standalone.yaml` |
| `RedisReplication` | 主从复制 | 需自行创建 CR |
| `RedisSentinel` | Sentinel 高可用 | 需自行创建 CR |
| `RedisCluster` | 集群模式 | 需自行创建 CR |

## 升级

```bash
# 更新离线 chart 后
helm upgrade redis-operator ./remote-redis-operator-0.24.0 \
  -n redis-operator -f ./values-prod.yaml
```

## 卸载

```bash
# 先删除 Redis 实例 CR（否则 PVC 会残留）
kubectl delete -f ../operator/
# 再卸载 operator
helm uninstall redis-operator -n redis-operator
kubectl delete namespace redis-operator --ignore-not-found
```
