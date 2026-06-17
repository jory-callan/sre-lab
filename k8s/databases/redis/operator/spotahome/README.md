# spotahome/redis-operator — Sentinel HA 高可用部署

基于 [spotahome/redis-operator](https://github.com/spotahome/redis-operator) 管理的 Redis Sentinel 高可用集群。
应用以 **单机模式（single-instance）** 连接，无需感知 Sentinel/Cluster。

---

## 设计决策

### 为什么不用 OT-CONTAINER-KIT sentinel-ha？

| 对比项 | OT-CONTAINER-KIT sentinel-ha | spotahome/redis-operator |
|--------|------------------------------|--------------------------|
| master 选举 | ❌ **强制 pod-0 为 master**（reconciliation loop） | ✅ **由 Sentinel 原生选举**，operator 不干预 |
| pod-0 重启行为 | 强制切回 pod-0 → 全量 RDB sync → 2+ 分钟不可用 | pod-0 自动成为 slave → 秒级恢复 |
| 切换时间 | 120s+ | < 30s（sentinel 检测 + 选举） |
| 维护状态 | ✅ 活跃维护 | ⚠️ 已归档（2026-06-11），但代码稳定可用 |
| 连接方式 | 单机/Service | 单机/Service |

### 核心结论

**即使 spotahome/redis-operator 已归档，它仍然是"应用单机连接 + Sentinel 高可用"场景的最优选择。**
其 reconciliation loop **不干预** Sentinel 的 master 选举——这正是 OT 做不到的。

---

## 架构

```
┌──────────────────────────────────────────────────────┐
│                  namespace: redis-spotahome           │
│                                                       │
│  ┌──────────────────────┐     ┌───────────────────┐  │
│  │  redisoperator (Pod) │     │  Auth Secret       │  │
│  │  quay.io/spotahome/  │     │  key: "password"  │  │
│  │  redis-operator      │     └────────┬──────────┘  │
│  └──────────┬───────────┘              │             │
│             │ reconcile loop (30s)     │             │
│             ▼                          │             │
│  ┌──────────────────────────────────────┐           │
│  │  StatefulSet: rfr-redisfailover-ha   │           │
│  │  ┌─────────┐  ┌─────────┐  ┌──────┐ │           │
│  │  │ pod-0   │  │ pod-1   │  │ pod-2│ │           │
│  │  │ 5Gi PVC │  │ 5Gi PVC │  │5GiPVC│ │           │
│  │  └────┬────┘  └────┬────┘  └──┬───┘ │           │
│  │       │slave       │master     │slave│           │
│  │       │            │           │     │           │
│  └───────┼────────────┼───────────┼─────┘           │
│          │            │           │                  │
│          │     ┌──────┴──────┐    │                  │
│          │     │ Service     │    │                  │
│          │     │ rfrm-...    │    │                  │
│          │     │ ClusterIP   │    │                  │
│          │     │ :6379       │    │                  │
│          │     └──────┬──────┘    │                  │
│          │            │           │                  │
│  ┌───────┴────────────┼───────────┴──────┐           │
│  │  Deployment: rfs-redisfailover-ha     │           │
│  │  ┌─────────┐  ┌─────────┐  ┌──────┐  │           │
│  │  │ sentinel│  │ sentinel│  │sentnl│  │           │
│  │  │ pod-1   │  │ pod-2   │  │pod-3 │  │           │
│  │  └─────────┘  └─────────┘  └──────┘  │           │
│  └───────────────────────────────────────┘           │
└──────────────────────────────────────────────────────┘

Service 自动跟随 master（label: redisfailovers-role=master）：
  rfrm-redisfailover-ha  →  当前 master pod（6379）

外部访问（NodePort 30206）：
  任意节点 IP:30206  →  当前 master

应用连接方式（单机模式）：
  redis://:password@rfrm-redisfailover-ha.redis-spotahome.svc:6379
```

### 关键行为

| 事件 | 行为 | 中断时间 |
|------|------|----------|
| master Pod 宕机 | Sentinel 检测（15s）→ 选举新 master → Service 更新 | ~15-30s |
| master Pod 恢复 | 自动成为 slave，**不会强制切回 master** | 0s（不中断） |
| slave Pod 宕机 | StatefulSet 自动重建 → 增量同步 | 0s（master 仍在） |
| slave Pod 恢复 | 自动重新同步 | 0s |
| Sentinel Pod 宕机 | Deployment 自动重建 | 0s（quorum=2，剩余 2 个仍可工作） |

---

## 部署

### 前提

- Kubernetes 1.21+（支持 CRD v1）
- 默认 StorageClass（本环境为 `nfs-storage`）
- Helm 3（用于下载 operator 镜像）

### 快速开始

```bash
# 一键部署（默认命名空间 redis-spotahome，默认密码 redis@czw）
./install.sh

# 自定义命名空间和密码
./install.sh my-redis my-secure-password
```

### 分步部署

```bash
# 1. 创建命名空间
kubectl create ns redis-spotahome

# 2. 创建密码 Secret（key 必须为 "password"）
kubectl create secret generic redis-auth \
  -n redis-spotahome \
  --from-literal=password='redis@czw'

# 3. 部署 CRD + RBAC + Operator
kubectl apply -f 00-operator.yaml

# 4. 创建 RedisFailover CR
kubectl apply -f 01-redisfailover-cr.yaml

# 5. 等待就绪
kubectl wait --for=condition=available -n redis-spotahome deployment/redisoperator --timeout=120s
kubectl get pods -n redis-spotahome -w
```

---

## 验证

### 三步基础验证

```bash
# 设置密码变量
PASS='redis@czw'

# 1/3 PING
kubectl exec -n redis-spotahome deployment/rfr-redisfailover-ha \
  -- redis-cli -a "$PASS" PING
# 期望: PONG

# 2/3 SET/GET
kubectl exec -n redis-spotahome deployment/rfr-redisfailover-ha \
  -- redis-cli -a "$PASS" SET verify:test "ok"
kubectl exec -n redis-spotahome deployment/rfr-redisfailover-ha \
  -- redis-cli -a "$PASS" GET verify:test
# 期望: OK → "ok"

# 3/3 Sentinel 确认 master
kubectl exec -n redis-spotahome deployment/rfs-redisfailover-ha \
  -- redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster
# 期望: <pod-IP> 6379
```

### 验证主从复制

```bash
# 查看每个 pod 的角色
for i in 0 1 2; do
  ROLE=$(kubectl exec -n redis-spotahome rfr-redisfailover-ha-$i \
    -- redis-cli -a "$PASS" ROLE | head -1)
  echo "pod-$i: $ROLE"
done

# 确认 Service 指向 master
kubectl get endpoints -n redis-spotahome rfrm-redisfailover-ha
# 期望: 只显示当前 master pod 的 IP
```

### 验证 Pod 标签跟随角色

```bash
# operator 会为 Redis pod 设置 redisfailovers-role 标签
for i in 0 1 2; do
  LABEL=$(kubectl get pod -n redis-spotahome rfr-redisfailover-ha-$i \
    -o jsonpath='{.metadata.labels.redisfailovers-role}')
  echo "pod-$i: redisfailovers-role=$LABEL"
done
# 期望: 0=slave, 1=master, 2=slave（或类似分布）
```

---

## 故障转移测试

### Kill master

```bash
# 找当前 master
MASTER=$(kubectl exec -n redis-spotahome deployment/rfr-redisfailover-ha \
  -- redis-cli -a "$PASS" ROLE | head -1)
echo "当前 master: $MASTER"

# 写数据验证
kubectl exec -n redis-spotahome deployment/rfr-redisfailover-ha \
  -- redis-cli -a "$PASS" SET failover:test "before_kill"

# 记录时间并 kill master
date +%H:%M:%S
kubectl delete pod -n redis-spotahome rfr-redisfailover-ha-0

# 每隔 5s 检查 failover
for i in $(seq 1 12); do
  sleep 5
  MASTER=$(kubectl get endpoints -n redis-spotahome rfrm-redisfailover-ha \
    -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null)
  echo "$(date +%H:%M:%S) master=$MASTER"
done
# 期望: ~15-30s 后 master IP 切换
```

### 验证 pod-0 恢复后不被强制切换

```bash
# 等待 pod-0 恢复
kubectl get pods -n redis-spotahome -w

# 检查角色
for i in 0 1 2; do
  ROLE=$(kubectl exec -n redis-spotahome rfr-redisfailover-ha-$i \
    -- redis-cli -a "$PASS" ROLE | head -1)
  echo "pod-$i: $ROLE"
done

# 关键验证：pod-0 必须是 slave，不是 master！
# 如果看到 pod-0=master，说明 operator 强制切换了（应该不会发生）
```

---

## 连接方式

### 集群内部（应用连接）

```
redis://:redis@czw@rfrm-redisfailover-ha.redis-spotahome.svc:6379
```

应用只需用单机模式连接这个 Service，无需任何 Sentinel/Cluster 感知的客户端库。

Service `rfrm-redisfailover-ha` 使用 selector `redisfailovers-role: master`，始终指向当前 master pod。

### 集群外部

```
redis://:redis@czw@<任意节点IP>:30206
```

通过 NodePort 30206 暴露。受限于 K8s 多节点，每个节点都会暴露这个端口，但**只有存在 master pod 的节点才是可写的**。建议在连接代码中配置多个节点 IP 的 fallback。

---

## 配置参考

### RedisFailover CR 字段说明

| 字段 | 说明 | 当前值 |
|------|------|--------|
| `auth.secretPath` | 引用 Secret 名，key 必须为 "password" | `redis-auth` |
| `redis.replicas` | Redis 实例数 | 3 |
| `sentinel.replicas` | Sentinel 实例数 | 3 |
| `redis.storage.persistentVolumeClaim` | PVC 定义 | 5Gi, nfs-storage |
| `redis.storage.keepAfterDeletion` | CR 删除后保留 PVC | true |
| `sentinel.customConfig` | Sentinel 自定义配置 | see below |
| `redis.customConfig` | Redis 自定义配置 | see below |

### Sentinal 自定义配置

```yaml
sentinel:
  customConfig:
    - "down-after-milliseconds 15000"   # 判定 master 宕机时限（默认 5000）
    - "failover-timeout 30000"          # 故障转移超时（默认 10000）
```

默认值 `5000` / `10000` 偏激进，容易在网络抖动时误触发 failover。
调大为 `15000` / `30000`，在故障检测速度和误判之间取得平衡。

### Redis 自定义配置

```yaml
redis:
  customConfig:
    - "tcp-keepalive 60"               # TCP keepalive：60s 探活
    - "min-replicas-to-write 1"        # 至少 1 个 slave 同步才可写
    - "min-replicas-max-lag 10"        # slave 延迟超过 10s 视为不同步
    - "repl-timeout 60"                # 主从复制超时
    - "repl-backlog-size 104857600"    # 复制积压缓冲区 100MB
```

### 资源配比

| 组件 | request | limit | 说明 |
|------|---------|-------|------|
| Operator | 10m / 50Mi | 100m / 50Mi | 极轻量，仅 reconcile |
| Redis | 200m / 256Mi | 500m / 512Mi | 3 个 pod，共 1.5C / 1.5Gi |
| Sentinel | 100m / 100Mi | 200m / 200Mi | 3 个 pod，共 0.6C / 0.6Gi |
| **总计** | **~0.9C / 1Gi** | **~1.7C / 2Gi** | |

> ⚠️ k3s 节点只有 2C，总计 3 Redis + 3 Sentinel + 1 Operator = 7 pods。注意总 request 不要超过节点容量。

---

## 默认值

| 配置项 | 默认值 | 来源 |
|--------|--------|------|
| Redis 镜像 | `redis:6.2.6-alpine` | [defaults.go](https://gh-proxy.com/https://github.com/spotahome/redis-operator/blob/master/api/redisfailover/v1/defaults.go) |
| Exporter 镜像 | `quay.io/oliver006/redis_exporter:v1.43.0` | 同上 |
| Sentinel down-after-milliseconds | 5000 | 同上 |
| Sentinel failover-timeout | 10000 | 同上 |
| Redis replica-priority | 100 | 同上 |

如果不需要 exporter，在 CR 的 `redis` 或 `sentinel` 部分设置 `exporter: false`（或 omit）。

---

## 卸载

```bash
# 一键卸载
./uninstall.sh

# 指定命名空间
./uninstall.sh my-redis
```

卸载流程：
1. 删除 RedisFailover CR → 级联删除 StatefulSet/Deployment/PVC/Service/ConfigMap
2. 删除 00-operator.yaml → 级联删除 Deployment/RBAC/CRD
3. 删除命名空间 → 清理所有残留

> ⚠️ `storage.keepAfterDeletion: true` 时，PVC 会在 CR 删除后保留，需手动清理。

---

## 稳定性分析

### Reconciliation loop

- Operator 每 **30 秒**（`resync`）reconcile 一次
- Sentinel 存活时 → **不干预** master 选举，仅修正 pod 角色标签
- Sentinel 全挂时 → 调用 `SetOldestAsMaster`（兜底策略）
- 正常运行时 → 等待 sentinel，不碰 master

### 已知风险

1. **项目已归档**：2026-06-11 归档，无新版本发布。但代码稳定，1.2k+ stars，社区已验证多年。
2. **Bug: sentinel 串接**（[#550](https://github.com/spotahome/redis-operator/issues/550)）：多个独立的 RedisFailover CR 在特定场景下 sentinel 会相互发现。**单集群单 CR 场景不受影响**。

   > ✅ 我们的部署就是单 CR，不存在此问题。

3. **单 StatefulSet 限制**（[#565](https://github.com/spotahome/redis-operator/issues/565)）：所有 Redis pod 属于同一个 StatefulSet，批量重启时 master 也会重启。但 Sentinel HA 的 fast failover 机制保证了秒级恢复。

### HA 能力矩阵

| 故障场景 | 影响 | 恢复方式 | 中断时间 |
|----------|------|----------|----------|
| master pod 宕机 | 写中断 | Sentinel 选举新 master | 15-30s |
| master pod 慢/hang | 写超时 | Sentinel 检测 + 选举 | 15-30s |
| slave pod 宕机 | 无 | StatefulSet 重建 | 0s |
| 节点宕机 | 节点上所有 pod 宕 | kube-scheduler 重新调度 + Sentinel 选举 | 30-60s |
| 网络分区 | 可能 split-brain | Sentinel 多数派 quorum=2 | depends |
| operator 自身宕机 | reconciliation 暂停 | Deployment 自动重建 | 0s（不影响运行中的 Redis） |

### 与 OT-CONTAINER-KIT 的负载对比

我们的测试集群验证：

```
场景: kill pod-0（当前 master）

OT-CONTAINER-KIT:
  T+0s    delete pod-0
  T+15s   sentinel 选举 pod-1 为 master（可用）
  T+30s   pod-0 恢复
  T+31s   OT reconciliation 强制切回 pod-0
  T+31s   开始全量 RDB sync（pod-1 → pod-0）
  T+150s+ sync 完成，pod-0 成为 master
  总不可用时间: ~2min+

spotahome/redis-operator:
  T+0s    delete pod-0
  T+15s   sentinel 选举 pod-1 为 master（可用）
  T+30s   pod-0 恢复，自动成为 slave
  T+15s   增量同步 start | end
  总不可用时间: ~15s
```

---

## 常见问题

### Q: 应用连接 Redis 需要用什么客户端库？

A: 普通 Redis 客户端即可。连接模式：`redis://:password@rfrm-redisfailover-ha.redis-spotahome.svc:6379`。
无需 Sentinel 感知/Cluster 感知的客户端。如果 master 切换，连接会断开，应用应实现重试逻辑。

### Q: 为什么不用 OC-CONTAINER-KIT 了？

A: 看上面的"设计决策"一节。核心原因是 OT 强制 pod-0 为 master，导致故障转移后重新同步时间太长。

### Q: 密码在哪里配？

A: `02-external.yaml` 中的 Secret 和 `01-redisfailover-cr.yaml` 中的 `auth.secretPath`。
确保 Secret 的 key 名为 `password`（operator 硬编码）。

### Q: 如何查看当前 master？

```bash
# 方法 1: 通过 Sentinel
kubectl exec -n redis-spotahome deployment/rfs-redisfailover-ha \
  -- redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster

# 方法 2: 通过 Service Endpoint
kubectl get endpoints -n redis-spotahome rfrm-redisfailover-ha

# 方法 3: 直接查 pod 标签
kubectl get pods -n redis-spotahome -l redisfailovers-role=master -o wide
```

### Q: 如何扩缩容 Redis 实例？

修改 `01-redisfailover-cr.yaml` 中的 `redis.replicas` 并 `kubectl apply -f`。
**注意**：replicas 通常设为 3（1主2从）。设为 1 或 2 时 Sentinel 仍然工作（但 quorum 需对应调整）。

### Q: Redis 版本太旧（6.2.6），如何升级？

在 CR 的 `redis` 部分指定 `image: redis:7.2-alpine`：

```yaml
spec:
  redis:
    image: redis:7.2-alpine
    replicas: 3
```

Sentinel 也可以独立指定镜像版本（`sentinel.image`）。

---

## 参考

- [spotahome/redis-operator GitHub](https://github.com/spotahome/redis-operator)
- [CRD 类型定义](https://github.com/spotahome/redis-operator/blob/master/api/redisfailover/v1/redisfailover_types.go)
- [默认配置](https://github.com/spotahome/redis-operator/blob/master/api/redisfailover/v1/defaults.go)
- [示例目录](https://github.com/spotahome/redis-operator/tree/master/example/redisfailover)