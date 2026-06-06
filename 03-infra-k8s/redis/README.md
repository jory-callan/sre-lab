# Redis — 内存缓存/数据库（Operator 方式）

基于 [OT-CONTAINER-KIT/redis-operator](https://github.com/OT-CONTAINER-KIT/redis-operator) 部署，
支持三种独立模式，每个模式完全自包含（secret + CR + service + PDB）。

## 部署架构

```
┌────────────────────────────────────────────┐
│  namespace: redis-operator                 │
│  redis-operator (Pod) — 管理所有 Redis CR  │
└────────────────────┬───────────────────────┘
                     │ 声明式 CR（各自独立）
    ┌────────────────┼────────────────┐
    ▼                ▼                ▼
 standalone     sentinel-ha       cluster
 NodePort:30003  NodePort:30004   (集群内访问)
   1 Pod          3+3 Sentinel     6 Pod (3主3从)
```

| 模式 | 适用场景 | Pod 数 | 高可用 | NodePort |
|------|---------|--------|--------|----------|
| **standalone** | 开发/轻量缓存 | 1 | ❌ | 30003 |
| **sentinel-ha** | 生产高可用（推荐） | 3 Redis + 3 Sentinel | ✅ 自动故障转移 | 30004 |
| **cluster** | 大规模数据分片 | 6 (3主3从) | ✅ 分片 + 故障转移 | 不暴露 |

## 快速开始

```bash
# 安装 operator + standalone（默认）
./install.sh

# 指定模式
./install.sh standalone       # 单节点
./install.sh sentinel-ha      # Sentinel 高可用（生产推荐）
./install.sh cluster          # 集群模式
```

## 验收确认

```bash
# 查看 operator
kubectl get pods -n redis-operator

# 查看 Redis 实例
kubectl get pods -n redis
kubectl get redis,redisreplication,rediscluster -n redis

# standalone 连接测试
redis-cli -h <节点IP> -p 30003 -a 'redis@czw' ping

# sentinel-ha 连接测试
redis-cli -h <节点IP> -p 30004 -a 'redis@czw' SENTINEL masters
```

## 卸载

```bash
# 只删指定模式，保留 operator
./uninstall.sh standalone
./uninstall.sh sentinel-ha
./uninstall.sh cluster

# 卸载全部（含 operator）
./uninstall.sh all
```

## 目录结构

```
redis/
├── helm/                                   # redis-operator Chart（唯一共享层）
│   ├── remote-redis-operator-0.24.0/       # 离线 Chart（禁止修改）
│   ├── values-prod.yaml                    # operator 资源配置
│   └── README.md                           # 离线安装说明
├── operator/
│   ├── standalone/                         # 完全自包含
│   │   ├── 00-secret.yaml                  # 认证密码
│   │   ├── 01-redis-cr.yaml                # Redis CR（AOF + maxmemory + anti-affinity）
│   │   ├── 02-service-external.yaml        # NodePort:30003
│   │   └── 03-pdb.yaml                     # PodDisruptionBudget
│   ├── sentinel-ha/                        # 完全自包含
│   │   ├── 00-secret.yaml
│   │   ├── 01-replication-cr.yaml          # Replication CR（内嵌 Sentinel）
│   │   ├── 02-service-external.yaml        # NodePort:30004
│   │   └── 03-pdb.yaml
│   └── cluster/                            # 完全自包含
│       ├── 00-secret.yaml
│       ├── 01-redis-cluster-cr.yaml         # Cluster CR（3主3从）
│       └── 02-pdb.yaml
├── install.sh
├── uninstall.sh
├── README.md
└── 踩坑记录.md
```

## 配置说明

### 存储

默认使用 `nfs-storage` StorageClass：
- standalone/sentinel-ha: 5Gi 每 Pod
- cluster: 10Gi 每 Pod + 1Gi node.conf

如需修改 StorageClass，编辑对应 CR 中的 `spec.storage.volumeClaimTemplate.spec.storageClassName`。

### 镜像

| 组件 | 镜像 | 协议 |
|------|------|------|
| Redis | quay.io/opstree/redis:v7.0.15 | **BSD**（v7.4+ 改为 SSPL/RSAL） |
| Sentinel | quay.io/opstree/redis-sentinel:latest | 同上 |
| Redis Exporter | quay.io/opstree/redis-exporter:v1.44.0 | Apache 2.0 |
| Operator | quay.io/opstree/redis-operator:v0.24.0 | Apache 2.0 |

⚠️ **必须使用 operator 定制镜像**，官方 redis 镜像没有密码注入/配置合并的 entrypoint hook。

### 密码

默认密码 `redis@czw`（每个模式目录下的 `00-secret.yaml`）。

生产部署前必须修改：

```bash
# 生成随机密码
PASSWORD=$(openssl rand -base64 16)

# 替换每个模式目录下的 secret
for mode in standalone sentinel-ha cluster; do
  sed -i "s/password:.*/password: \"$PASSWORD\"/" operator/$mode/00-secret.yaml
done
```

### 持久化

- AOF: appendfsync everysec（每秒 fsync，折中性能与安全）
- RDB: 沿用 operator 默认 save 策略（3600s/1, 300s/100, 60s/10000）
- maxmemory: 内存 limit 的 80%（`maxMemoryPercentOfLimit: 80`）
- 逐出策略: `noeviction`（生产安全，缓存场景改为 `allkeys-lru`）

## 模式选型建议

### standalone
- **适用**：开发环境、小缓存、可接受单点故障
- **不适用**：核心生产数据、会话/队列/锁

### sentinel-ha ✅ 生产默认推荐
- **适用**：大多数生产场景
- **特性**：1 主 2 从 + 3 Sentinel，故障自动切换
- **资源**：3 Pod × 5Gi PVC + 3 Sentinel Pod（轻量）

### cluster
- **适用**：数据量大需分片，客户端支持 Redis Cluster
- **特性**：3 主 3 从，自动分片 slot
- **资源**：6 Pod × 10Gi PVC + 6 × 1Gi node.conf PVC
- **注意**：只在明确需要分片时启用

## 已知坑点

详见 [踩坑记录.md](./踩坑记录.md)：

1. ⚠️ Sentinel 必须内嵌在 `RedisReplication` CR 中，不要创建独立 `RedisSentinel` CR（不支持密码认证）
2. ⚠️ Sentinel quorum 等数值字段必须使用字符串类型
3. ⚠️ 必须使用 operator 定制镜像（`quay.io/opstree/redis`），官方镜像没有密码注入 hook