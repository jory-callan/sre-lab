# Redis - 内存缓存/数据库（Operator 方式）

基于 [OT-CONTAINER-KIT/redis-operator](https://github.com/OT-CONTAINER-KIT/redis-operator) 部署，
支持三种模式切换，安装时指定即可。

## 部署架构

```
┌────────────────────────────────────────────┐
│  namespace: redis-operator                 │
│  redis-operator (Pod) — 管理所有 Redis CR  │
└────────────────────┬───────────────────────┘
                     │ 声明式 CR
    ┌────────────────┼────────────────┐
    ▼                ▼                ▼
 standalone     sentinel-ha       cluster
 NodePort:30003  NodePort:30004    (无 NodePort)
```

| 模式 | 适用场景 | 实例数 | 高可用 |
|------|---------|--------|--------|
| **standalone** | 开发/轻量缓存 | 1 | ❌ |
| **sentinel-ha** | 生产高可用 | 3 主从 + 3 sentinel | ✅ 自动故障转移 |
| **cluster** | 大规模数据分片 | 6 (3主3从) | ✅ 分片 + 故障转移 |

## 快速开始

```bash
# 安装 operator + standalone（默认）
./install.sh

# 指定模式
./install.sh standalone       # 单实例
./install.sh sentinel-ha      # Sentinel 高可用
./install.sh cluster          # 集群模式

# 卸载（只删指定模式，保留 operator）
./uninstall.sh standalone
./uninstall.sh sentinel-ha
./uninstall.sh cluster

# 卸载全部（含 operator）
./uninstall.sh all
```

## 验收确认

```bash
# 查看 operator
kubectl get pods -n redis-operator

# 查看 Redis 实例
kubectl get pods -n redis
kubectl get redis,redisreplication,redissentinel,rediscluster -n redis

# standalone 连接测试
redis-cli -h <节点IP> -p 30003 -a 'redis@czw' ping
```

## 目录结构

```
redis/
├── helm/                              # redis-operator Chart
│   ├── remote-redis-operator-0.24.0/  # 离线 Chart（禁止修改）
│   ├── values-prod.yaml               # operator 资源配置
│   └── README.md                      # 离线安装说明
├── operator/
│   ├── common/                        # 所有模式共享资源
│   │   └── 00-secret.yaml             # 认证密码
│   ├── standalone/                    # 单实例模式
│   │   ├── redis-cr.yaml
│   │   └── service-external.yaml      # NodePort:30003
│   ├── sentinel-ha/                   # Sentinel 高可用
│   │   ├── replication-cr.yaml        # 1主2从
│   │   ├── sentinel-cr.yaml           # 3 sentinel
│   │   └── service-external.yaml      # NodePort:30004
│   └── cluster/                       # 集群模式
│       └── redis-cluster-cr.yaml      # 3主3从
├── install.sh                         # 安装入口
├── uninstall.sh                       # 卸载入口
└── README.md
```

## 注意

- operator 只装一次，切换模式只需 `./install.sh <模式>`
- 同时部署多种模式也可以（会拉不同 CR，占用更多资源）
- 默认密码 `redis@czw`，部署后请修改
- `quay.io/opstree/redis:v7.0.15` 为 BSD 协议（v7.4+ 改为 SSPL/RSAL）
