# Redis on Kubernetes — 选型、部署与运维手册

> 基于 OT-CONTAINER-KIT/redis-operator v0.24.0 | k3s 集群环境 | 2026-06

---

## 目录

1. [选型分析](#1-选型分析)
   - 1.1 [为什么选 OT-CONTAINER-KIT redis-operator](#11-为什么选-ot-container-kit-redis-operator)
   - 1.2 [候选方案对比](#12-候选方案对比)
   - 1.3 [不推荐方案](#13-不推荐方案)
   - 1.4 [关于 Redis 许可证的说明](#14-关于-redis-许可证的说明)
2. [架构总览](#2-架构总览)
   - 2.1 [整体架构](#21-整体架构)
   - 2.2 [模式对比速查](#22-模式对比速查)
   - 2.3 [三种模式详解](#23-三种模式详解)
   - 2.4 [目录结构](#24-目录结构)
3. [部署指南](#3-部署指南)
   - 3.1 [前提条件](#31-前提条件)
   - 3.2 [安装 operator](#32-安装-operator)
   - 3.3 [部署 Standalone](#33-部署-standalone)
   - 3.4 [部署 Sentinel-HA（生产推荐）](#34-部署-sentinel-ha生产推荐)
   - 3.5 [部署 Cluster](#35-部署-cluster)
   - 3.6 [验收确认](#36-验收确认)
   - 3.7 [连接方式](#37-连接方式)
   - 3.8 [修改密码](#38-修改密码)
   - 3.9 [卸载](#39-卸载)
4. [稳定性与脑裂分析](#4-稳定性与脑裂分析)
   - 4.1 [脑裂基本概念](#41-脑裂基本概念)
   - 4.2 [Standalone 脑裂风险](#42-standalone-脑裂风险)
   - 4.3 [Sentinel-HA 脑裂风险](#43-sentinel-ha-脑裂风险)
   - 4.4 [Cluster 脑裂风险](#44-cluster-脑裂风险)
   - 4.5 [Anti-fencing 配置详解](#45-anti-fencing-配置详解)
   - 4.6 [K8s 环境特有风险](#46-k8s-环境特有风险)
   - 4.7 [Operator Reconciliation Loop 行为](#47-operator-reconciliation-loop-行为)
5. [生产配置建议](#5-生产配置建议)
   - 5.1 [资源规划](#51-资源规划)
   - 5.2 [持久化策略](#52-持久化策略)
   - 5.3 [内存管理](#53-内存管理)
   - 5.4 [网络调优](#54-网络调优)
   - 5.5 [高可用保障](#55-高可用保障)
   - 5.6 [监控与告警](#56-监控与告警)
   - 5.7 [备份策略](#57-备份策略)
   - 5.8 [存储考量（NFS 场景）](#58-存储考量nfs-场景)
6. [常用命令速查](#6-常用命令速查)
   - 6.1 [连接测试](#61-连接测试)
   - 6.2 [信息查看](#62-信息查看)
   - 6.3 [Key 操作](#63-key-操作)
   - 6.4 [配置操作](#64-配置操作)
   - 6.5 [集群管理（Cluster 模式）](#65-集群管理cluster-模式)
   - 6.6 [Sentinel 管理（Sentinel-HA 模式）](#66-sentinel-管理sentinel-ha-模式)
   - 6.7 [K8s 运维命令](#67-k8s-运维命令)
7. [常见排错指南](#7-常见排错指南)
   - 7.1 [Pod 启动失败 / CrashLoopBackOff](#71-pod-启动失败--crashloopbackoff)
   - 7.2 [密码认证失败 AUTH failed](#72-密码认证失败-auth-failed)
   - 7.3 [主从同步失败](#73-主从同步失败)
   - 7.4 [Sentinel 显示 master sdown](#74-sentinel-显示-master-sdown)
   - 7.5 [集群 Pod 一直 Pending](#75-集群-pod-一直-pending)
   - 7.6 [磁盘空间不足](#76-磁盘空间不足)
   - 7.7 [Redis OOM / 内存超限](#77-redis-oom--内存超限)
   - 7.8 [脑裂恢复](#78-脑裂恢复)
   - 7.9 [连接超时 / 拒绝连接](#79-连接超时--拒绝连接)
   - 7.10 [Cluster 集群状态异常](#710-cluster-集群状态异常)
   - 7.11 [Operator 更新配置不生效](#711-operator-更新配置不生效)
   - 7.12 [修改 CR 后 Pod 没有重启](#712-修改-cr-后-pod-没有重启)
8. [附录](#8-附录)
   - 8.1 [参考链接](#81-参考链接)
   - 8.2 [配置速查表](#82-配置速查表)
   - 8.3 [已知坑点汇总](#83-已知坑点汇总)

---

## 1. 选型分析

### 1.1 为什么选 OT-CONTAINER-KIT redis-operator

OT-CONTAINER-KIT/redis-operator（以下简称 OT operator）是当前 K8s 上部署 Redis 的较优选择，原因：

| 维度 | 说明 |
|------|------|
| **模式支持** | 原生支持 standalone / RedisReplication（含 Sentinel）/ RedisCluster 三种 CRD |
| **声明式管理** | 通过 CR 定义期望状态，operator 自动 reconcile，无需手动维护 StatefulSet |
| **密码集成** | 原生支持 `redisSecret` 字段，自动注入密码到 Redis 和 Sentinel |
| **监控集成** | 内置 Redis Exporter 支持，开箱即用 Prometheus 指标 |
| **持久化** | 原生 PVC 声明、RDB/AOF 配置，无需额外脚本 |
| **抗亲和性** | 原生 `spec.affinity` 字段，支持跨节点调度 |
| **许可证** | Apache 2.0（operator 本身），开源无商业风险 |
| **成熟度** | 4000+ GitHub Star，CNCF Landscape，已有生产部署案例 |

### 1.2 候选方案对比

| 方案 | 模式支持 | 复杂度 | 密码 | 持久化 | 监控 | 许可证 | 推荐度 |
|------|----------|--------|------|--------|------|--------|--------|
| **OT operator** | standalone/sentinel/cluster | 中 | ✅ 原生 | ✅ 原生 | ✅ 原生 | Apache 2.0 | ⭐⭐⭐⭐⭐ |
| Bitnami Helm Chart | standalone/sentinel/cluster | 低 | ✅ | ✅ | ✅ | 需 Bitnami 协议 | ❌ 排除 |
| 自写 Helm / 裸 StatefulSet | 自行实现 | 高 | 自写 | 自写 | 自写 | 无限制 | ⭐⭐ |
| KubeDB | 全支持 | 高 | ✅ | ✅ | ✅ | 部分功能付费 | ⭐⭐⭐ |
| Valkey Operator | 有限 | 中 | 部分 | 部分 | 部分 | Apache 2.0 | 待观察 |

### 1.3 不推荐方案

- **Bitnami redis chart** — 用户已明确排除。另外 Bitnami 的容器入口脚本做了大量包装，出问题时排查路径长
- **自写 StatefulSet + Sentinel 脚本** — Sentinel 和 Cluster 的坑很多（Pod IP 变化后的 announce 配置、slot 迁移、pvc 重绑定、rolling update 顺序），自己维护长期负担重
- **Redis 官方 Enterprise Operator** — 需商业订阅，不适合本项目
- **社区无人维护的 Helm chart** — 安全风险，被废弃后无保障

### 1.4 关于 Redis 许可证的说明

| Redis 版本 | 许可证 | 备注 |
|-----------|--------|------|
| v7.0.x 及以下 | **BSD 3-Clause** | 完全开源，商用无风险 |
| v7.4+ | SSPL / RSAL v2 | 云服务商收费，内部使用不受限 |
| Valkey (Redis fork) | **Apache 2.0** | Linux Foundation 托管，协议完全自由 |

> 本部署使用 `quay.io/opstree/redis:v7.0.15`（v7.0 最后一个版本），仍为 BSD 协议。
> 如未来需要升级，建议迁移到 Valkey 镜像（Apache 2.0）。

---

## 2. 架构总览

### 2.1 整体架构

```
┌────────────────────────────────────────────────────────┐
│  namespace: redis-operator                             │
│  ┌────────────────────────────────────────┐            │
│  │ redis-operator (Pod)                    │            │
│  │  - watches CR (Redis/RedisReplication/  │            │
│  │    RedisCluster)                        │            │
│  │  - creates StatefulSet + Service + PVC  │            │
│  │  - 自动注入密码、合并配置、管理 Exporter │            │
│  │  - reconcilation loop 保证期望状态      │            │
│  └────────────┬───────────────────────────┘            │
└───────────────┼────────────────────────────────────────┘
                │ 声明式 CR (各自独立，互不依赖)
    ┌───────────┼───────────────┐
    ▼           ▼               ▼
┌─────────┐ ┌─────────┐ ┌────────────┐
│standalone│ │sentinel │ │  cluster   │
│         │ │  -ha    │ │            │
│ 1 Pod   │ │ 3+3 Pod │ │ 3主3从=6Pod│
│:30003   │ │:30004   │ │ 集群内访问 │
└─────────┘ └─────────┘ └────────────┘
```

三种模式通过各自的 CRD（Redis / RedisReplication / RedisCluster）声明期望状态，operator 监听 CR 变化并自动调谐 StatefulSet、Service、PVC。

### 2.2 模式对比速查

| 特性 | Standalone | Sentinel-HA | Cluster |
|------|-----------|-------------|---------|
| **Pod 数** | 1 | 3 Redis + 3 Sentinel | 6（3 主 3 从） |
| **高可用** | ❌ 无 | ✅ 自动故障转移 | ✅ 自动故障转移 + 分片 |
| **脑裂风险** | 无 | 低（有兜底配置） | 低-中 |
| **分片** | 无 | 无 | ✅ 16384 slot 自动分片 |
| **客户端要求** | 任何客户端 | 支持 Sentinel discovery | 支持 Cluster 协议 |
| **NodePort** | 30003 | 30004（Sentinel） | 不暴露 |
| **数据持久化** | 5Gi PVC × 1 | 5Gi PVC × 3 | 10Gi PVC × 6 + 1Gi node.conf × 6 |
| **PDB** | minAvailable: 1 | minAvailable: 2 | minAvailable: 3 |
| **资源请求** | 200m / 256Mi | 500m / 512Mi | 200m / 256Mi |
| **适用场景** | 开发/轻量缓存 | ✅ **生产推荐** | 大规模数据分片 |

### 2.3 三种模式详解

#### 2.3.1 Standalone（单节点模式）

**CRD**: `Redis`（`redis.redis.opstreelabs.in/v1beta2`）

创建一个 Redis 实例，无高可用。

**适用场景**：
- 开发环境
- 少量缓存数据可重建
- 可接受单点故障的业务

**不适用于**：
- 核心生产数据
- 会话存储
- 队列 / 分布式锁

**连接**：
```
集群外: redis-cli -h <节点IP> -p 30003 -a '<密码>'
集群内: redis-cli -h redis-standalone.redis.svc.cluster.local -p 6379 -a '<密码>'
```

#### 2.3.2 Sentinel-HA（主从复制 + 哨兵高可用，生产推荐）

**CRD**: `RedisReplication`（`redis.redis.opstreelabs.in/v1beta2`）

创建 1 主 2 从的主从复制组，外加 3 个 Sentinel Pod 自动监控。

**关键架构特征**：
- Sentinel **内嵌**在 RedisReplication CR 中，不创建独立的 `RedisSentinel` CR
- Sentinel Pod 命名模式：`redis-replication-s-0/1/2`
- 密码通过 `kubernetesConfig.redisSecret` 自动注入 sentinel
- Sentinel 的 `quorum`、`parallelSyncs`、`failoverTimeout`、`downAfterMilliseconds` 等数值字段**必须使用字符串类型**

**故障转移流程**：
```
1. Master 宕机 / 网络隔离
   ↓
2. Sentinel 检测到 PING 超时 → master 标记 SDOWN（主观下线）
   ↓
3. 向其他 sentinel 询问 → quorum=2 个同意 → 标记 ODOWN（客观下线）
   ↓
4. Sentinel 集群选举 Leader → 发起 failover
   ↓
5. Sentinel 选 replica 中数据最新的升为 master
   ↓
6. 另一 replica 指向新 master → 故障转移完成
```

**连接**：
```
# 通过 Sentinel 获取当前 master 地址（可达 Sentinel 的客户端）
redis-cli -h <节点IP> -p 30004 -a '<密码>' SENTINEL get-master-addr-by-name mymaster

# 直接连 master（集群内）
redis-cli -h redis-replication-0.redis-replication-headless.redis.svc.cluster.local -p 6379 -a '<密码>'
```

#### 2.3.3 Cluster（集群模式）

**CRD**: `RedisCluster`（`redis.redis.opstreelabs.in/v1beta2`）

创建 3 主 3 从的 Redis Cluster，自动分片 16384 个 slot。

**关键特征**：
- 每个 Pod 独立 PVC（10Gi 数据 + 1Gi node.conf）
- leader 和 follower 可独立配置（`redisLeader.redisConfig` / `redisFollower.redisConfig`）
- 支持 `clusterVersion: v7`
- 不支持 `spec.affinity` 字段（CRD 定义中无此字段）
- 内置 gossip 协议自动发现节点
- slot 迁移由 Redis 自身管理（非 operator 管理）

**适用场景**：
- 单节点内存不够，需要水平扩展
- 大量数据的缓存场景（> 几十 GB）
- 客户端已支持 Redis Cluster（如 go-redis ClusterClient）

**不适用于**：
- 小数据集（3 主 3 从的 overhead 不值得）
- 客户端不支持 cluster 协议

**连接**：
```
# 集群内（-c 开启 cluster 模式，自动重定向）
redis-cli -h redis-cluster.redis.svc.cluster.local -p 6379 -c -a '<密码>'
```

### 2.4 目录结构

```
03-infra-k8s/redis/
├── helm/                                    # operator Chart（不可修改）
│   └── remote-redis-operator-0.24.0/
├── install.sh                               # 一键安装（operator + 指定模式）
├── uninstall.sh                             # 卸载脚本
├── README.md                                # 快速开始文档
├── 踩坑记录.md                               # 已知坑点
├── 命令速查.md                               # 日常运维命令
├── Redis选型与运维手册.md                     # ⬅ 本文档
└── operator/
    ├── standalone/
    │   ├── 00-external-config.yaml          # ConfigMap: 额外配置
    │   ├── 00-secret.yaml                   # 密码 Secret
    │   ├── 01-redis-cr.yaml                 # Redis CR
    │   ├── service-external.yaml            # NodePort 30003
    │   └── 03-pdb.yaml                      # PDB
    ├── sentinel-ha/
    │   ├── 00-external-config.yaml          # ConfigMap: 防脑裂/网络配置
    │   ├── 00-secret.yaml
    │   ├── 01-replication-cr.yaml           # RedisReplication CR（内嵌 Sentinel）
    │   ├── service-external.yaml            # NodePort 30004
    │   └── 03-pdb.yaml
    └── cluster/
        ├── 00-external-config.yaml          # ConfigMap: cluster 额外配置
        ├── 00-secret.yaml
        ├── 01-redis-cluster-cr.yaml         # RedisCluster CR
        └── 02-pdb.yaml
```

---

## 3. 部署指南

### 3.1 前提条件

- Kubernetes 集群（测试环境为 k3s 3 节点）
- Helm 3+
- 默认 StorageClass（或已创建 `nfs-storage`）
- 国内网络：NGINX Ingress 已部署（kite.czw-sre.internal 域名指向中控台）
- 系统盘 40GB → 确保 Redis PVC 不落在系统盘（已配置 StorageClass 指向数据盘）

### 3.2 安装 operator

```bash
cd 03-infra-k8s/redis/
./install.sh          # 默认安装 operator + standalone 模式
```

operator 是全局共享组件，安装一次即可。后续切换模式只需：

```bash
./install.sh standalone       # 部署 standalone
./install.sh sentinel-ha      # 切换或新增 sentinel-ha
./install.sh cluster          # 切换或新增 cluster
```

不同模式可以共存（CR 各自独立）。

**operator 验证**：

```bash
kubectl get pods -n redis-operator
# 期望输出:
# NAME                               READY   STATUS    RESTARTS   AGE
# redis-operator-f5d7d9f7b-8krnj    1/1     Running   0          5m

kubectl get crd | grep redis.opstreelabs
# 期望输出 3 个 CRD:
# redisclusters.redis.redis.opstreelabs.in
# redis.redis.redis.opstreelabs.in
# redisreplications.redis.redis.opstreelabs.in
```

### 3.3 部署 Standalone

```bash
./install.sh standalone
```

验证：

```bash
# 查看 Pod
kubectl get pods -n redis -l app=redis-standalone
# NAME                 READY   STATUS    RESTARTS   AGE
# redis-standalone-0   2/2     Running   0          2m   # redis + exporter

# 连接测试
redis-cli -h 192.168.5.249 -p 30003 -a 'redis@czw' ping
# 期望: PONG

# 读写测试
redis-cli -h 192.168.5.249 -p 30003 -a 'redis@czw' SET test:key hello
# 期望: OK
redis-cli -h 192.168.5.249 -p 30003 -a 'redis@czw' GET test:key
# 期望: "hello"

# 配置验证
redis-cli -h 192.168.5.249 -p 30003 -a 'redis@czw' CONFIG GET tcp-keepalive
# 期望: 1) "tcp-keepalive"  2) "60"

# 持久化验证
redis-cli -h 192.168.5.249 -p 30003 -a 'redis@czw' INFO persistence
# 期望: aof_enabled:1, aof_rewrite_in_progress:0
```

### 3.4 部署 Sentinel-HA（生产推荐）

```bash
./install.sh sentinel-ha
```

验证：

```bash
# 查看所有 Pod
kubectl get pods -n redis -l app=redis-replication
# NAME                        READY   STATUS    RESTARTS   AGE
# redis-replication-0         2/2     Running   0          3m   # master
# redis-replication-1         2/2     Running   0          3m   # replica
# redis-replication-2         2/2     Running   0          3m   # replica

kubectl get pods -n redis -l redis_setup_type=sentinel
# NAME                           READY   STATUS    RESTARTS   AGE
# redis-replication-s-0          1/1     Running   0          3m
# redis-replication-s-1          1/1     Running   0          3m
# redis-replication-s-2          1/1     Running   0          3m

# Sentinel 状态
redis-cli -h 192.168.5.249 -p 30004 SENTINEL masters
# 期望: status=ok

# 查看主从复制状态
redis-cli -h 192.168.5.249 -p 30003 -a 'redis@czw' INFO replication
# 期望: role:master, connected_slaves:2
```

#### 故障转移测试

```bash
# 手动删除 master（模拟宕机）
kubectl delete pod -n redis redis-replication-0

# 等待 15-30 秒，观察 sentinel 自动切换
kubectl get pods -n redis -w

# 查看当前 master
redis-cli -h <节点IP> -p 30004 SENTINEL get-master-addr-by-name mymaster
# 期望: 返回新的 master Pod IP
```

### 3.5 部署 Cluster

```bash
./install.sh cluster
```

验证：

```bash
# 查看所有 Pod（6 个）
kubectl get pods -n redis -l redis_cluster=redis-cluster
# NAME                        READY   STATUS    RESTARTS   AGE
# redis-cluster-leader-0      2/2     Running   0          5m
# redis-cluster-leader-1      2/2     Running   0          5m
# redis-cluster-leader-2      2/2     Running   0          5m
# redis-cluster-follower-0    2/2     Running   0          5m
# redis-cluster-follower-1    2/2     Running   0          5m
# redis-cluster-follower-2    2/2     Running   0          5m

# 集群状态
kubectl exec -n redis redis-cluster-leader-0 -- redis-cli -a 'redis@czw' cluster info
# 期望: cluster_state:ok
#        cluster_slots_assigned:16384
#        cluster_known_nodes:6

# 集群节点列表
kubectl exec -n redis redis-cluster-leader-0 -- redis-cli -a 'redis@czw' cluster nodes

# 读写测试
kubectl exec -n redis redis-cluster-leader-0 -- redis-cli -a 'redis@czw' -c SET test:cluster hello
# 期望: OK （可能跳过 Redirect）
kubectl exec -n redis redis-cluster-leader-0 -- redis-cli -a 'redis@czw' -c GET test:cluster
# 期望: "hello"

# Slot 分布
kubectl exec -n redis redis-cluster-leader-0 -- redis-cli -a 'redis@czw' cluster slots
```

### 3.6 验收确认

三种模式通用的三步验收：

```bash
# 1. 所有 Pod Running
kubectl get pods -n redis                # 全部 Running 且 Ready

# 2. Ping 通
redis-cli -h <IP> -p <端口> -a '<密码>' ping
# → PONG

# 3. 读写正常
redis-cli -h <IP> -p <端口> -a '<密码>' SET sre:verify ok
redis-cli -h <IP> -p <端口> -a '<密码>' GET sre:verify
# → "ok"
# → DEL sre:verify
```

### 3.7 连接方式

| 场景 | Standalone | Sentinel-HA | Cluster |
|------|-----------|-------------|---------|
| **集群外** | `-h <节点IP> -p 30003` | `-h <节点IP> -p 30004`（连 Sentinel） | 不暴露，集群内访问 |
| **集群内** | `redis-standalone.redis:6379` | `通过 Sentinel 获取 master` | `redis-cluster.redis:6379 -c` |
| **Go 客户端** | `redis.NewClient()` | `redis.NewFailoverClient()` | `redis.NewClusterClient()` |

### 3.8 修改密码

```bash
# 生成随机密码
PASSWORD=$(openssl rand -base64 16)
echo "新密码: $PASSWORD"

# 替换所有模式的 secret
for mode in standalone sentinel-ha cluster; do
  sed -i '' "s/password:.*/password: $PASSWORD/" operator/$mode/00-secret.yaml
done

# 重新 apply
kubectl apply -f operator/standalone/00-secret.yaml
kubectl apply -f operator/sentinel-ha/00-secret.yaml
kubectl apply -f operator/cluster/00-secret.yaml

# 重启所有 Pod（operator 不会自动检测密码变更）
kubectl rollout restart sts -n redis --all
```

> ⚠️ 密码修改后所有现有连接会中断，客户端需要更新密码重连。

### 3.9 卸载

```bash
# 卸载指定模式（保留 operator 和其他模式）
./uninstall.sh standalone
./uninstall.sh sentinel-ha
./uninstall.sh cluster

# 卸载全部（含 operator）
./uninstall.sh all
```

---

## 4. 稳定性与脑裂分析

### 4.1 脑裂基本概念

**脑裂（Split-Brain）**：集群因网络分区被分割成多个独立部分，每部分都认为自己是正常集群，各自独立运行，最终导致数据不一致。

在 Redis 中，脑裂的风险路径：

```
网络分区发生
  ↓
一侧检测到 master 不可达 → 触发 failover → 选出新 master
  ↓
另一侧仍认为旧 master 是主 → 持续写入
  ↓
分区恢复 → 两个 master 同时存在 → 数据冲突
```

### 4.2 Standalone 脑裂风险

**风险：无**

Standalone 只有一个节点，没有故障转移机制，不存在脑裂场景。如果节点宕机，服务直接不可用。

### 4.3 Sentinel-HA 脑裂风险

**风险：低（配置恰当后接近零）**

**脑裂路径**：

```
网络分区（如交换机故障）
  ↓
节点 A（原 master）与 Sentinel 之间断连
  ↓
至少 2 个 Sentinel 判定 master ODOWN
  ↓
执行 failover，选 replica B 为新 master
  ↓
此时存在 2 个 master（A 写入，B 写入）
  ↓
分区恢复 → 数据冲突
```

**防护机制（本部署已全部配置）**：

| 防护层 | 参数 | 值 | 作用 |
|--------|------|----|------|
| **写入仲裁** | `min-replicas-to-write` | 1 | 🛡️ **核心防线**：分区期间如果所有 replica 失联，master 拒绝写入，脑裂期间不会有新数据 |
| **Replica 延迟** | `min-replicas-max-lag` | 10 | replica 延迟超 10s → master 停止写入，防止数据不一致 |
| **Sentinel 超时** | `downAfterMilliseconds` | 15000 | 网络抖动 15s 内不触发 failover |
| **Quorum** | `quorum` | 2 | 至少 2 个 sentinel 同意才 failover |
| **TCP 探测** | `tcp-keepalive` | 60s | 快速检测死连接，避免 TCP 假死 |
| **复制缓冲区** | `repl-backlog-size` | 100MB | 网络中断后 replica 可增量同步，降低全量 RDB 压力 |

**综上，Sentinel-HA 脑裂概率极低。** 最大风险场景是网络分区同时导致：
- Sentinel 全部在一侧（无法凑够 quorum）
- 旧 master 在一侧（数据写入继续）
- 这种场景在大多数 K8s 网络拓扑下概率极低

### 4.4 Cluster 脑裂风险

**风险：中低**

Redis Cluster 使用 gossip 协议和一致性合约。当节点超时（`cluster-node-timeout`）无心跳时，被标记为 PFAIL（可能故障），如果 majority 认为节点不可达，标记为 FAIL。

**防护机制**：

| 参数 | 值 | 作用 |
|------|----|------|
| `cluster-node-timeout` | 15000ms | 网络抖动容忍 15s |
| `tcp-keepalive` | 60s | 快速检测死连接 |
| `repl-backlog-size` | 100MB | 增量同步缓冲区 |

**Cluster 脑裂的核心区别**：Redis Cluster 的 n/2+1 一致性保障意味着 minority 侧会直接拒绝写入（`CLUSTERDOWN`），不会像 Sentinel 那样出现"两个 master 都在写入"的经典脑裂。但代价是 minority 侧完全不可用。

**风险场景**：

```
3 节点分区成 2+1（如交换机故障）
  ↓
2 节点侧：majority（quorum），继续服务
  ↓
1 节点侧：minority，拒绝所有写入 → CLUSTERDOWN
  ↓
分区恢复 → 1 节点侧的数据未丢失（因为它根本没写入新数据）
```

所以 Redis Cluster 数据一致性更好，但可用性更低（minority 完全不可用）。

### 4.5 Anti-fencing 配置详解

本部署为每个模式配置了专门的 ConfigMap，提供 anti-fencing 配置：

#### Standalone

```conf
tcp-keepalive 60          # 网络稳定性，快速检测死连接
```

Standalone 无需 anti-fencing（无故障转移），仅保留基础网络调优。

#### Sentinel-HA

```conf
min-replicas-to-write 1   # ⭐ 防脑裂核心：replica 全掉线时 master 停写
min-replicas-max-lag 10   # replica 延迟超过 10s 停写
tcp-keepalive 60          # TCP 层：60s 探测死连接
repl-timeout 60           # 复制超时 60s（默认 60s，显式保留）
repl-backlog-size 104857600  # 100MB 复制积压缓冲区
```

#### Cluster

```conf
cluster-node-timeout 15000  # ⭐ Cluster 防脑裂核心
tcp-keepalive 60
repl-timeout 60
repl-backlog-size 104857600
```

### 4.6 K8s 环境特有风险

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| **节点故障** | Pod 重新调度，IP 变化 | StatefulSet 保证稳定网络标识 + PVC 保留数据 |
| **Pod 驱逐** | 主动/被动驱逐导致重启 | PDB + podAntiAffinity + 资源预留 |
| **网络抖动** | Sentinel 误判 master 下线 | downAfterMilliseconds=15000 容忍 |
| **NFS 延迟** | AOF 写入慢，Redis 阻塞 | 生产推荐替换为 Local SSD，AOF everysec |
| **OOM Kill** | Redis 超内存限制被杀 | maxMemoryPercentOfLimit=80% + limits 合理设置 |
| **Operator 升级** | CRD 变动，Pod 重建 | 参考官方 migration guide 逐步升级 |
| **DNS 解析慢** | Sentinel 之间通信超时 | 使用 `.svc.cluster.local` 域名 + 稳定的 CoreDNS |

### 4.7 Operator Reconciliation Loop 行为

OT operator 使用 reconciliation loop 持续将实际状态调整为 CR 中声明的期望状态。

**重要**：

- `kubectl scale sts redis-replication --replicas=5` 不会生效 — operator 会立即将 replica 数重置回 CR 中的 `clusterSize: 3`
- `kubectl delete pod` 后 Pod 会被自动重建
- `kubectl edit sts` 对 Pod 模板的修改会被覆盖
- 所有期望状态的修改必须在 CR 中完成

**正确做法**：

```bash
# 修改 CR（支持重新 apply）
kubectl apply -f operator/sentinel-ha/01-replication-cr.yaml

# operator 自动检测变化，更新 StatefulSet
# Pod 会自动 rolling update
```

---

## 5. 生产配置建议

### 5.1 资源规划

| 模式 | CPU request | Memory request | CPU limit | Memory limit | 建议节点数 |
|------|------------|---------------|-----------|-------------|-----------|
| Standalone | 200m | 256Mi | 1 | 1Gi | 1 |
| Sentinel-HA | 500m | 512Mi | 2 | 2Gi | ≥3（跨节点） |
| Cluster | 200m | 256Mi | 1 | 1Gi | ≥3（跨节点） |
| Sentinel Pod | 50m | 64Mi | 200m | 128Mi | — |

> 2C 节点部署多组件时需适当下调 request 值，否则 Pod 会 `Pending`。
> Sentinel-HA 的 500m/512Mi 为生产推荐值，低资源环境可降到 200m/256Mi。

### 5.2 持久化策略

| 配置 | standalone | sentinel-ha | cluster | 说明 |
|------|-----------|-------------|---------|------|
| AOF | everysec | everysec | everysec | 每秒 fsync，折中性能与安全 |
| RDB | 默认 save | 默认 save | 默认 save | Operator 默认策略，主从自动触发 |
| maxmemory | limit 的 80% | limit 的 80% | limit 的 80% | 避免 OOM |
| PVC | 5Gi | 5Gi | 10Gi + 1Gi | Cluster 额外需要 node.conf PVC |

**RDB 默认 save 策略**（operator 内置）：
```
save 3600 1        # 3600 秒内有 ≥1 次写入 → 触发 RDB
save 300 100       # 300 秒内有 ≥100 次写入 → 触发 RDB
save 60 10000     # 60 秒内有 ≥10000 次写入 → 触发 RDB
```

### 5.3 内存管理

```bash
# 查看当前内存使用
redis-cli -p 30003 -a '<密码>' INFO memory
redis-cli -p 30003 -a '<密码>' MEMORY STATS

# 查看 maxmemory
redis-cli -p 30003 -a '<密码>' CONFIG GET maxmemory

# 手动查看最大内存和已用
redis-cli -p 30003 -a '<密码>' INFO memory | grep -E 'used_memory_human|maxmemory_human'
```

**逐出策略（maxmemory-policy）**：

| 策略 | 适用场景 | 说明 |
|------|---------|------|
| `noeviction` | 业务数据/队列/锁 ✅ | 超过 maxmemory 后拒绝写入，适合有可靠内存规划的生产环境 |
| `allkeys-lru` | 缓存场景 | 淘汰最近最少使用的 key，适用于临时缓存 |
| `allkeys-lfu` | 缓存热点 | 淘汰最不常用的 key，比 LRU 更准确 |
| `volatile-lru` | 混合场景 | 仅淘汰设置了 TTL 的 key |
| `volatile-ttl` | — | 淘汰 TTL 最短的 key |

**推荐**：
- **生产核心数据**：`noeviction`（默认）— 明确拒绝写入，让上层业务感知并处理
- **缓存**：`allkeys-lru` — 允许自动淘汰

### 5.4 网络调优

| 配置 | 值 | 说明 |
|------|-----|------|
| `tcp-keepalive` | 60 | 60 秒发送探测包，快速检测死连接 |
| `repl-timeout` | 60 | 复制超时（默认 60，显式保留） |
| `repl-backlog-size` | 100MB | 复制积压缓冲区，网络中断后增量同步 |
| `downAfterMilliseconds` | 15000 | Sentinel 判定节点下线的时间 |
| `cluster-node-timeout` | 15000 | Cluster 节点心跳超时 |

### 5.5 高可用保障

| 措施 | 说明 |
|------|------|
| **PodDisruptionBudget** | Standalone: minAvailable=1, Sentinel-HA: minAvailable=2, Cluster: minAvailable=3 |
| **podAntiAffinity** | preferred（软约束），倾向跨节点调度，但不阻塞创建 |
| **多副本** | Sentinel-HA 1 主 2 从共 3 副本，容忍 1 节点故障 |
| **Sentinel 3 节点 + quorum=2** | 容忍 1 个 sentinel 故障 |
| **StatefulSet** | 稳定网络标识 + 有序滚动更新 + PVC 保留 |

### 5.6 监控与告警

**内置 Exporter**：

每个 Redis Pod 旁有一个 `redis-exporter` sidecar，暴露 Prometheus 指标在 `:9121`。

```
kubectl port-forward -n redis redis-standalone-0 9121:9121
curl localhost:9121/metrics
```

**推荐 PrometheusRule**（需部署 Prometheus + ServiceMonitor 后添加）：

```yaml
# 示例告警规则
groups:
- name: redis
  rules:
  - alert: RedisDown
    expr: redis_up == 0
    for: 1m
    severity: critical

  - alert: RedisMemoryHigh
    expr: redis_memory_used_bytes / redis_memory_max_bytes > 0.8
    for: 5m
    severity: warning

  - alert: RedisReplicationBroken
    expr: redis_connected_slaves < 2
    for: 1m
    severity: critical
```

**关键指标**：

| 指标 | 说明 | 正常范围 |
|------|------|---------|
| `redis_up` | Redis 是否在线 | 1 |
| `redis_memory_used_bytes` | 已用内存 | < maxmemory |
| `redis_connected_clients` | 客户端连接数 | 视业务 |
| `redis_connected_slaves` | 从节点连接数（HA/Cluster） | 2 / 3 |
| `redis_master_last_io_seconds_ago` | 与主节点最后一次 IO（从节点） | < 60 |
| `redis_rdb_last_bgsave_status` | 最后一次 RDB 状态 | ok |
| `redis_aof_last_rewrite_status` | 最后一次 AOF 重写状态 | ok |
| `redis_keyspace_hits / redis_keyspace_misses` | 缓存命中率 | 越高越好 |

### 5.7 备份策略

**推荐方案一：定期 RDB 拷贝**

```bash
#!/bin/bash
# 从 Redis Pod 中拷贝 RDB 文件
NAMESPACE=redis
BACKUP_DIR=/data/backup/redis
DATE=$(date +%Y%m%d-%H%M)

for mode in standalone replication cluster; do
  POD=$(kubectl get pods -n $NAMESPACE -l app=redis-$mode -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -n "$POD" ]; then
    mkdir -p $BACKUP_DIR/$mode
    kubectl exec -n $NAMESPACE $POD -- sh -c 'cat /data/dump.rdb' > $BACKUP_DIR/$mode/dump-$DATE.rdb
  fi
done

# 保留最近 7 天
find $BACKUP_DIR -name "*.rdb" -mtime +7 -delete
```

**推荐方案二：Redis SLAVE 触发 BGSAVE**

```bash
# 找一个 replica 节点触发 BGSAVE（不对 master 产生性能影响）
redis-cli -h redis-replication-1.redis-replication-headless.redis.svc.cluster.local \
  -p 6379 -a '<密码>' BGSAVE

# 等待完成后拷出 /data/dump.rdb
```

**备份建议**：
- 至少每天一次备份
- 保留最近 7 天
- 生产建议异地备份（跨集群/对象存储）
- 定期演练恢复流程

### 5.8 存储考量（NFS 场景）

> ⚠️ 本部署使用 NFS（`nfs-storage` StorageClass）作为数据存储。
> NFS 对 Redis 不是最优选择，以下是风险与应对：

| 风险 | 影响 | 缓解 |
|------|------|------|
| **NFS 延迟** | AOF fsync 可能被阻塞 | AOF everysec（折中）、避免 always |
| **NFS 单点** | NFS 故障 → 所有 Redis 无法写入 | NFS 自身 HA（如集群 NFS） |
| **网络依赖** | NFS 网络抖动 → Redis 响应变慢 | 同网段部署 NFS 服务 |
| **性能上限** | 并发压力大时 NFS 成为瓶颈 | 热点业务拆分到独立 Redis |

**生产建议**：改用 Local SSD + PV 静态绑定或 Rook/Ceph 分布式存储。

---

## 6. 常用命令速查

### 6.1 连接测试

```bash
# PING（最基础的健康检查）
redis-cli -h 192.168.5.249 -p 30003 -a 'redis@czw' PING
# → PONG

# 带认证的连接
redis-cli --no-auth-warning -h 192.168.5.249 -p 30003 -a 'redis@czw'
```

### 6.2 信息查看

```bash
# Redis 基础信息
INFO server          # 版本/进程/运行时间
INFO replication     # 主从复制状态
INFO sentinel        # 哨兵状态（sentinel-ha）
INFO memory          # 内存使用
INFO persistence     # AOF/RDB 持久化
INFO stats           # 统计信息
INFO clients         # 客户端连接
INFO cluster         # 集群状态（cluster）

# 慢查询
SLOWLOG GET 10       # 查看最近 10 条慢查询
SLOWLOG LEN          # 慢查询队列长度
SLOWLOG RESET        # 清空慢查询日志

# 客户端管理
CLIENT LIST          # 查看所有连接
CLIENT KILL <addr>   # 断开指定连接
CLIENT GETNAME       # 查看当前连接名
```

### 6.3 Key 操作

```bash
# 基础
SET key value [EX 10] [NX] [XX]     # 设置 key，可选过期/NX不存在/XX存在
GET key                              # 获取值
DEL key1 key2                        # 删除 key
EXISTS key                           # 是否存在
TYPE key                             # 类型

# 过期
EXPIRE key 60                        # 设置 60s 过期
TTL key                              # 查看剩余时间（-1 永不过期，-2 已过期）
PERSIST key                          # 移除过期

# 批量
KEYS *                               # 匹配所有 key（生产慎用，可能阻塞）
SCAN 0 COUNT 100                     # 游标式迭代，推荐生产使用
KEYS prefix:*                        # 匹配前缀（生产慎用）

# 统计
DBSIZE                               # 当前库 key 数量
INFO keyspace                        # 各库 key 分布
RANDOMKEY                            # 随机返回一个 key

# 结构操作
SADD set member                      # Set 添加
HSET hash field value                # Hash 设置
LPUSH list value                     # List 左侧推入
ZADD zset score member               # Sorted Set 添加
```

### 6.4 配置操作

```bash
# 查看配置
CONFIG GET *                          # 查看所有配置（输出量大）
CONFIG GET tcp-keepalive              # 查看单个配置
CONFIG GET append*                    # 通配符匹配

# 运行时修改（重启后丢失，仅用于临时调试）
CONFIG SET tcp-keepalive 60
CONFIG SET requirepass newpassword    # ⚠️ 运行时改密码要小心

# 持久化配置（需改 CR + ConfigMap，见排错章节）
```

### 6.5 集群管理（Cluster 模式）

```bash
# 集群状态
CLUSTER INFO                          # 集群状态、slot 分配
CLUSTER NODES                         # 所有节点信息
CLUSTER SLOTS                         # slot 分布详情

# 集群操作
CLUSTER MEET <ip> <port>              # 添加节点到集群（operator 自动管理）
CLUSTER FORGET <node-id>              # 移除节点
CLUSTER REPLICATE <master-id>         # 成为指定 master 的 replica
CLUSTER FAILOVER                      # 手动触发 failover（从节点执行）

# Slot 迁移（Redis Cluster 重分片）
CLUSTER SETSLOT <slot> MIGRATING <node-id>    # 标记 slot 迁移中
CLUSTER SETSLOT <slot> IMPORTING <node-id>    # 标记 slot 导入中
CLUSTER SETSLOT <slot> NODE <node-id>         # 将 slot 分配给新节点
MIGRATE <host> <port> <key> <db> <timeout>    # 迁移一个 key

# 检查集群完整性
redis-cli --cluster check 192.168.5.249:6379 -a 'redis@czw'
redis-cli --cluster fix   192.168.5.249:6379 -a 'redis@czw'   # 修复问题
redis-cli --cluster rebalance 192.168.5.249:6379               # 重新平衡 slot
```

### 6.6 Sentinel 管理（Sentinel-HA 模式）

```bash
# 连 Sentinel 端口
redis-cli -h <节点IP> -p 30004

# Sentinel 命令
SENTINEL masters                          # 查看所有监控的主节点
SENTINEL master mymaster                  # 查看指定主节点状态
SENTINEL slaves mymaster                  # 查看从节点列表
SENTINEL sentinels mymaster               # 查看其他 sentinel 节点
SENTINEL get-master-addr-by-name mymaster # 获取当前 master 地址
SENTINEL failover mymaster                # 手动触发 failover
SENTINEL monitor <name> <ip> <port> <q>   # 添加监控（运行时，重启丢失）
SENTINEL remove <name>                    # 移除监控
SENTINEL ckquorum mymaster                # 检查 sentinel 是否足够投票
SENTINEL pending-scripts                  # 查看待执行的脚本

# 获取当前 master 信息
SENTINEL get-master-addr-by-name mymaster
# 1) "10.42.1.20"
# 2) "6379"
```

### 6.7 K8s 运维命令

```bash
# Pod 操作
kubectl get pods -n redis -o wide       # 查看分布节点
kubectl describe pod -n redis redis-replication-0   # 查看事件/状态
kubectl logs -n redis redis-replication-0 redis     # Redis 日志
kubectl logs -n redis redis-replication-0 redis-exporter  # Exporter 日志

# 进入 Pod 内部 Redis-CLI
kubectl exec -it -n redis redis-standalone-0 -- redis-cli -a 'redis@czw'

# 查看 PV/PVC
kubectl get pvc -n redis
kubectl get pv | grep redis

# 查看 CR 状态
kubectl get redis -A                     # 查看所有 standalone CR
kubectl get redisreplication -A          # 查看所有 replication CR
kubectl get rediscluster -A              # 查看所有 cluster CR
kubectl describe redis -n redis redis-standalone     # CR 详情

# 查看 operator 日志
kubectl logs -n redis-operator deploy/redis-operator | tail -50

# 查看 events
kubectl get events -n redis --sort-by='.lastTimestamp'
```

---

## 7. 常见排错指南

### 7.1 Pod 启动失败 / CrashLoopBackOff

**检查步骤**：

```bash
# 1. 查看 Pod 事件
kubectl describe pod -n redis <pod-name>

# 2. 查看 Redis 日志
kubectl logs -n redis <pod-name> redis

# 3. 查看 Exporter 日志
kubectl logs -n redis <pod-name> redis-exporter

# 4. 检查 CR 配置是否合法
kubectl describe <crd-type> -n redis <cr-name>
```

**常见原因 & 解决**：

| 原因 | 特征日志 | 解决 |
|------|---------|------|
| PVC 创建失败 | `Failed to provision volume` | 检查 StorageClass 是否存在、NFS 是否正常 |
| 镜像拉取失败 | `ImagePullBackOff` | 检查镜像地址，国内网络加 `imagePullPolicy: IfNotPresent` |
| 资源不足 | `0/3 nodes are available` | `kubectl describe node` 查看可用资源，调低 request |
| 密码配置错误 | `AUTH failed` | 检查 Secret 是否存在、key 名是否匹配 |
| AOF 文件损坏 | `Bad file format` | 删除 AOF 文件重启：`redis-check-aof --fix /data/appendonly.aof` |
| 配置错误 | `Bad directive or wrong number of arguments` | 检查 external ConfigMap 格式 |

### 7.2 密码认证失败 AUTH failed

```bash
# 现象
(error) ERR AUTH <password> called without any password configured
(error) NOAUTH Authentication required
```

**排查**：

```bash
# 1. 检查 Secret 是否存在且内容正确
kubectl get secret -n redis redis-auth -o jsonpath='{.data.password}' | base64 -d

# 2. 检查 CR 是否正确引用 Secret
kubectl describe <crd> -n redis <name> | grep -A2 redisSecret

# 3. 检查镜像是否使用 operator 定制镜像
kubectl get pod -n redis <pod> -o jsonpath='{.spec.containers[0].image}'
# 必须: quay.io/opstree/redis:v7.0.15（官方镜像没有密码注入 hook）
```

### 7.3 主从同步失败

```bash
# 查看复制状态
redis-cli -p 30003 -a '<密码>' INFO replication
# 关注:
#   role:master / slave
#   master_link_status:up / down
#   slave_<N>: state=online / wait_bgsave / send_bulk
#   master_last_io_seconds_ago: 距离上次通信时间

# 查看复制错误
redis-cli -p 30003 -a '<密码>' INFO stats | grep sync_
#   sync_full: 全量同步次数（过高说明网络不稳定）
#   sync_partial_ok: 增量同步成功
#   sync_partial_err: 增量同步失败

# 查看 replica 的复制源
redis-cli -p 30003 -a '<密码'> INFO replication | grep master_host
```

**常见原因**：

| 原因 | 特征 | 解决 |
|------|------|------|
| 网络抖动 | `master_link_status: down`，`slave_repl_offset` 滞后 | 检查网络，增加 repl-backlog-size |
| 全量同步频繁 | `sync_full` 增长快 | 加大 repl-backlog-size，检查 replica 是否频繁重启 |
| RDB 传输阻塞 | `repl_backlog_histlen` 远小于 `repl_backlog_size` | 检查网络带宽，减少同时间同步 replica 数 |
| 主节点没有完整 RDB | `repl_backlog_active:0` | 检查主节点持久化是否正常 |

### 7.4 Sentinel 显示 master sdown

```bash
# 检查 sentinel 状态
SENTINEL master mymaster
# 关注: flags, num-other-sentinels, num-slaves, config-epoch

# 查看 sentinel 日志
kubectl logs -n redis <sentinel-pod>
```

**排查流程**：

```
1. sentinel 是否能看到 master？
   SENTINEL get-master-addr-by-name mymaster
   → 如果是空，说明 sentinel 未成功连接 master

2. 检查密码是否正确注入
   kubectl exec -n redis <sentinel-pod> -- env | grep MASTER_PASSWORD

3. 检查 sentinel 配置是否正确
   kubectl exec -n redis <sentinel-pod> -- cat /etc/redis/sentinel.conf

4. 检查 sentinel 是否使用了独立 RedisSentinel CR
   → 必须使用 RedisReplication CR 内嵌 sentinel！
```

**重要限制**：独立的 `RedisSentinel` CR 不支持密码认证。Sentinel 必须内嵌在 `RedisReplication` CR。

### 7.5 集群 Pod 一直 Pending

```bash
kubectl describe pod -n redis <pending-pod>
# 看 Events 字段
```

**常见原因**：

```bash
# 原因 1: 资源不足
Events:
  Warning  FailedScheduling  5s  default-scheduler  0/3 nodes are available: 3 Insufficient cpu
  → 调低 resource request 或增加节点

# 原因 2: PVC 绑定失败
Events:
  Warning  FailedScheduling  5s  default-scheduler  persistentvolumeclaim "..." not found
  → 检查 StorageClass 和 NFS 服务

# 原因 3: 节点 nodeSelector / taint 不匹配
Events:
  Warning  FailedScheduling  5s  default-scheduler  0/3 nodes are available: 3 node(s) didn't match pod anti-affinity
  → 节点数不足 3，或 anti-affinity 无法满足
```

### 7.6 磁盘空间不足

系统盘仅 40GB，日志/AOF 可能撑满。

```bash
# 检查磁盘
df -h
kubectl exec -n redis <pod> -- df -h /data

# 查看 Redis AOF/RDB 文件大小
kubectl exec -n redis <pod> -- du -sh /data/*.aof /data/*.rdb

# AOF 重写触发
redis-cli -p 30003 -a '<密码>' BGREWRITEAOF

# 手动清空 AOF（危险，仅在数据可丢失时）
kubectl exec -n redis <pod> -- sh -c '> /data/appendonly.aof'

# 检查日志轮转
# k3s server 自身的日志：
journalctl --vacuum-size=500M
# containerd 日志轮转：
ls -lh /var/lib/rancher/k3s/agent/containerd/ # 清理旧日志

# 控制 Redis log 级别（尽量少打印）
redis-cli -p 30003 -a '<密码>' CONFIG SET loglevel warning
```

### 7.7 Redis OOM / 内存超限

```bash
# 现象
(error) OOM command not allowed when used memory > 'maxmemory'.

# 查看内存使用
redis-cli -p 30003 -a '<密码>' INFO memory
# maxmemory_human:1.60G
# used_memory_human:1.70G  ← 已超限

# 紧急处理
# 1. 临时释放内存（运行时改逐出策略，慎用）
CONFIG SET maxmemory-policy allkeys-lru

# 2. 或用 UNLINK 删除大 key（不会阻塞）
UNLINK big:key

# 3. 或扩容
# 修改 CR 中的 limits.memory → 然后重启 Pod

# 长期方案
# - 调整 maxMemoryPercentOfLimit（默认 80% → 可降到 70%）
# - 检查内存泄漏
MEMORY DOCTOR           # Redis 7.0+ 的诊断工具
MEMORY MALLOC-STATS     # Jemalloc 内部统计
MEMORY PURGE            # 尝试释放碎片内存
```

### 7.8 脑裂恢复

如果已经发生脑裂（两个 master 都在）：

```bash
# 1. 确认哪一个是正确 master（数据最新的那个）
SENTINEL get-master-addr-by-name mymaster

# 2. 连接错误的 master，看它是否有新数据
redis-cli -h <错误masterIP> -p 6379 -a '<密码>'
# 检查 key 最后修改时间
OBJECT idletime <key>

# 3. 如果错误 master 有数据被误写入
# a. 先手动保存这些数据（用 DUMP/RESTORE 或 SCAN 导出）
# b. 将错误 master 降级为 replica
SLAVEOF <正确masterIP> 6379

# 4. 追回数据
# 如果错误 master 的数据来不及保存，可以用 AOF 恢复
# 进入错误 master 的 Pod
kubectl exec -it -n redis <pod> -- sh
cat /data/appendonly.aof   # 提取写入日志
```

**预防**（本部署已全配）：
- `min-replicas-to-write 1` — 分区期间 replica 全掉线时停写
- `downAfterMilliseconds 15000` — 15s 超时
- `quorum 2` — 至少 2 个 sentinel 同意才 failover

### 7.9 连接超时 / 拒绝连接

```bash
# 现象
Could not connect to Redis at <host>:<port>: Connection timed out
Connection refused
```

**排查**：

```bash
# 1. Pod 是否 Running
kubectl get pods -n redis

# 2. Service 端点是否正常
kubectl get endpoints -n redis
# 期望: ENDPOINTS 列显示 Pod IP

# 3. NodePort 是否监听
ss -tlnp | grep <NodePort>   # 在节点上执行

# 4. 防火墙是否放行
iptables -L -n | grep <端口>

# 5. 从另一个 Pod 测试连通性
kubectl run -it --rm tmp --image=redis:7-alpine -- redis-cli -h redis-standalone.redis -p 6379 -a '<密码>' ping

# 6. DNS 解析
kubectl run -it --rm tmp --image=busybox -- nslookup redis-standalone.redis
```

### 7.10 Cluster 集群状态异常

```bash
# 检查集群状态
CLUSTER INFO
# 期望: cluster_state:ok
# 异常: cluster_state:fail 或 cluster_slots_ok < 16384

# slot 分配检查
CLUSTER NODES
# 每个节点应有 slot 段

# 检查节点间通信
CLUSTER COUNT-keys-in-slot <slot>    # 查看指定 slot 的 key

# 修复
redis-cli --cluster fix <任意节点IP>:6379 -a '<密码>'
# 或
redis-cli --cluster check <任意节点IP>:6379 -a '<密码>'

# 重新均衡（需要所有节点在线）
redis-cli --cluster rebalance <任意节点IP>:6379 -a '<密码>'
```

**常见异常原因**：

| 现象 | 原因 | 解决 |
|------|------|------|
| `cluster_state:fail` | 某些 slot 无法访问（节点宕机） | 恢复宕机节点 |
| `cluster_slots_ok < 16384` | slot 未完全分配 | 手动分配缺失 slot 或 rebalance |
| `FAIL` 状态节点 | 节点被标记 FAIL | `CLUSTER FORGET` 移除 |
| `handshake` 状态 | 节点未完全加入 | 等待或 `CLUSTER MEET` |

### 7.11 Operator 更新配置不生效

**现象**：修改了 external ConfigMap 或 dynamicConfig，但 Pod 内配置未更新

**原因**：operator 的配置注入只在 Pod **启动时**发生。改变量配置不会热更新。

**解决方案**：

```bash
# 1. 更新 ConfigMap
kubectl apply -f operator/sentinel-ha/00-external-config.yaml

# 2. 重启 Pod 使配置生效
kubectl rollout restart sts -n redis redis-replication
# 或
kubectl delete pod -n redis <pod-name>  # operator 会自动重建

# 3. 验证配置已生效
redis-cli -p 30004 -a '<密码>' CONFIG GET tcp-keepalive
```

### 7.12 修改 CR 后 Pod 没有重启

**现象**：`kubectl apply -f 01-replication-cr.yaml` 后 Pod 没有变化

**原因**：operator 只在 CR 中**影响 StatefulSet 模板**的字段变化时触发滚动更新。修改 `additionalRedisConfig` 等配置引用不会自动重建 Pod（StatefulSet 本身没有变化）。这是因为 operator reconciler 只检测部分字段变化。

**解决方案**：

```bash
# 方法 1: 手动重启
kubectl rollout restart sts -n redis <sts-name>

# 方法 2: 删除 Pod（operator 会重建）
kubectl delete pod -n redis <pod>

# 方法 3: 触发 StatefulSet 更新（改一些影响模板的字段如 resources）
# 然后 operator 会触发滚动更新
```

---

## 8. 附录

### 8.1 参考链接

| 资源 | 链接 |
|------|------|
| OT-CONTAINER-KIT/redis-operator | https://github.com/OT-CONTAINER-KIT/redis-operator |
| 官方文档（CRD 参考） | https://github.com/OT-CONTAINER-KIT/redis-operator/tree/main/docs |
| 示例 YAML | https://github.com/OT-CONTAINER-KIT/redis-operator/tree/main/example |
| additional_config 示例 | https://github.com/OT-CONTAINER-KIT/redis-operator/blob/main/example/v1beta2/additional_config |
| Redis 官方文档 | https://redis.io/docs/ |
| Redis 配置参考 | https://redis.io/docs/management/config/ |
| Redis Sentinel 文档 | https://redis.io/docs/management/sentinel/ |
| Redis Cluster 文档 | https://redis.io/docs/management/scaling/ |
| Valkey（Redis fork） | https://valkey.io/ |
| Redis 许可证变更说明 | https://redis.com/blog/redis-adopts-dual-source-available-license/ |

### 8.2 配置速查表

**Anti-fencing / 防脑裂配置**：

| 参数 | Standalone | Sentinel-HA | Cluster | 作用 |
|------|-----------|-------------|---------|------|
| `tcp-keepalive` | 60 | 60 | 60 | TCP 层死连接检测 |
| `min-replicas-to-write` | — | 1 | — | ⭐ 防脑裂：replica 全掉线停写 |
| `min-replicas-max-lag` | — | 10 | — | replica 延迟超限停写 |
| `repl-backlog-size` | — | 100MB | 100MB | 复制缓冲区，网络中断增量同步 |
| `repl-timeout` | — | 60 | 60 | 复制超时 |
| `cluster-node-timeout` | — | — | 15000 | Cluster 心跳超时 |
| `downAfterMilliseconds` | — | 15000 | — | Sentinel 判定下线时间 |
| `quorum` | — | 2 | — | Sentinel 法定同意数 |

**生产推荐（全模式通用）**：

| 配置 | 推荐值 | 说明 |
|------|--------|------|
| `appendonly` | yes | 开启 AOF |
| `appendfsync` | everysec | 每秒 fsync |
| `maxmemory-policy` | noeviction | 业务数据用 noeviction，缓存用 allkeys-lru |
| `save` | 3600 1 / 300 100 / 60 10000 | operator 默认（不需要特别修改） |

### 8.3 已知坑点汇总

#### ⚠️ 严重坑点

1. **Sentinel 必须内嵌在 RedisReplication CR 中，不能使用独立 RedisSentinel CR**
   - 独立 RedisSentinel CR 不支持密码认证
   - 只能通过 RedisReplication 的 `spec.sentinel` 内嵌
   - 密码从 `kubernetesConfig.redisSecret` 自动继承

2. **Sentinel 数值字段必须是字符串**
   - `quorum`, `parallelSyncs`, `failoverTimeout`, `downAfterMilliseconds`
   - 写数字 → CRD 校验失败: `in body must be of type string`

3. **必须使用 operator 定制镜像**
   - `quay.io/opstree/redis:v7.0.15`
   - 官方 `redis:7.*` 没有密码注入、配置合并 entrypoint hook
   - 用错镜像 → 密码认证 100% 失败

4. **K8s scale 命令被 operator 覆盖**
   - `kubectl scale sts` 不会生效
   - operator reconciliation loop 会恢复为 CR 中的期望值
   - 修改副本数必须改 CR

5. **Cluster CR 不支持 affinity**
   - `RedisCluster` CRD 没有 `spec.affinity` 字段
   - 尝试设置 affinity → CRD 校验失败

#### ⚠️ 中等等级坑点

6. **修改 ConfigMap 后不会热更新 Pod**
   - ConfigMap 变更 → **必须** `kubectl rollout restart sts`
   - operator 不会自动检测 ConfigMap 变化重建 Pod

7. **dynamicConfig 只对部分配置生效**
   - 已验证生效：`appendonly`, `appendfsync`, `maxmemory-policy`
   - 不生效：`tcp-keepalive`, `min-replicas-*`, `repl-backlog-size`, `cluster-node-timeout`, `repl-timeout`
   - 不生效的配置必须放在 external ConfigMap 中，通过 `additionalRedisConfig` 引用

8. **NFS 作为 Redis 数据盘的性能风险**
   - AOF fsync 可能被 NFS 网络延迟阻塞
   - 生产推荐 Local SSD 替代
   - 如果必须用 NFS：`appendfsync everysec`（不要用 `always`）

9. **系统盘 40GB 限制**
   - 容器日志、AOF 文件可能撑满
   - 必须配置日志轮转
   - 确保 PVC 落在数据盘（非系统盘）

10. **国内网络镜像拉取问题**
    - `quay.io/opstree/redis:v7.0.15` 可能拉取慢
    - 提前 pull 到节点：`ctr image pull` 或通过代理拉取
    - 或使用内部 Harbor 缓存

---

> 最后更新：2026-06 | 工具: Hermes SRE v1.0.0 | 模型: ark-code-latest