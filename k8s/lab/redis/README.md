# Redis (OT-Container-KIT) — 选型与验证

## 为什么选 OT-Container-KIT？

| 候选方案 | 结论 | 理由 |
|---------|------|------|
| **OT-Container-KIT** | ✅ **当前选择** | 仓库已验证，1.4k stars，quay.io 镜像免限速，支持 Sentinel/Cluster/Standalone |
| Valkey Operator（hyperspike） | ❌ 待观望 | v0.0.61，API v1alpha1，302 stars，尚未 GA |
| 官方 Redis Operator（relibab） | ❌ 淘汰 | docker.io 镜像限速，社区不活跃 |
| KubeDB | ❌ 淘汰 | 多重，且已移除 |

### 关于 Valkey

Valkey（Linux Foundation 项目）是目前 Redis 协议兼容的优秀替代品。
OT-Container-KIT 作为 Operator 框架成熟稳定，而 Valkey 作为运行引擎可以
通过 **drop-in replacement** 的方式接入——Operator 不变，只换镜像名。

```
# 当前
image: quay.io/opstree/redis:v7.0.15

# 未来可换成 Valkey（drop-in）
image: docker.io/valkey/valkey:8.1
```

Valkey Operator 本身还要继续观望，但 Valkey 这个项目已经可以直接用。

详见 `valkey-compare/` 目录。

## 生产就绪特性

| 特性 | 说明 |
|------|------|
| **Sentinel 模式** | 1 主 2 从 + 3 哨兵，自动故障切换 |
| **主从复制** | 异步复制，replica 提供读负载 |
| **密码认证** | 通过 `redisSecret` 声明式管理 |
| **持久化** | AOF + RDB，PVC 挂载 |
| **节点反亲和** | 尽量分散到不同节点 |
| **自动重建** | StatefulSet 管理，Pod 删除后自动恢复 |
| **Prometheus Exporter** | 端口 9121，自动暴露 |
| **TLS** | 可选，需要额外配置 |

## 支持的模式

| CRD | 模式 | 场景 |
|------|------|------|
| `RedisReplication` | 主从复制 | HA 数据层（当前使用） |
| `RedisSentinel` | 哨兵 | HA 仲裁层（当前使用） |
| `RedisCluster` | 分片集群 | 大规模数据分片 |
| `Redis` | Standalone | 单机测试/开发 |

## 目录说明

```
lab/redis/
├── README.md                   ← 本文件
├── operator/                   ← Operator 安装说明
│   └── README.md
├── standalone/                 ← 单实例测试
│   ├── redis-single.yaml
│   └── quick-start.sh
├── sentinel-ha/                ← 生产级 1主2从+3哨兵
│   ├── redis-replication.yaml
│   ├── redis-sentinel.yaml
│   ├── secret.yaml
│   ├── monitoring.yaml
│   ├── chaos-test.sh
│   └── kustomization.yaml
└── valkey-compare/             ← Valkey 对比分析
    └── README.md
```

## 部署顺序（测试环境）

```bash
# 1. 安装 Operator
kubectl apply -k ../operator/
kubectl -n redis-operator wait pod -l app.kubernetes.io/name=redis-operator --for=condition=Ready

# 2. 单机测试
kubectl apply -f standalone/redis-single.yaml

# 3. 清理单机，上 sentinel HA
kubectl delete -f standalone/redis-single.yaml
kubectl apply -k sentinel-ha/

# 4. 运行混沌测试
bash sentinel-ha/chaos-test.sh all
```
