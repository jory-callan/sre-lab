# Redis — 内存缓存/数据库（Deployment 方式 🔄）

> **备份方案** — 用于节点断电后 Pod 自动迁移场景。
> 基于原生 Deployment（非 Operator），K8s 1.19+ 可用，无需特定 operator 版本。
> 当前仅支持 **standalone 模式**（单实例），不适合生产高可用核心链路。

---

## 1. 方案背景与动机

### 为什么要用 Deployment？

**问题**：StatefulSet 在节点断电后 Pod 不会自动迁移。

```
节点掉电 → Pod Terminating → StatefulSet 等待旧 Pod 完全消失 → 永远等不到 → ❌
```

**原因**：StatefulSet controller 认为 Terminating 状态的 Pod 仍然"存在"，不创建替换 Pod。

**Deployment 的行为**：

```
节点掉电 → Pod Terminating → ReplicaSet 过滤掉 Terminating Pod → 立即创建新 Pod → ✅
```

这是 ReplicaSet 的底层逻辑——`filterActivePods()` 函数直接排除 Terminating 状态的 Pod。

### 适用场景

| 场景 | 推荐方案 |
|------|---------|
| 开发/测试环境、轻量缓存 | ✅ Deployment standalone |
| 可接受短时中断的辅助服务 | ✅ Deployment standalone |
| 生产核心数据、会话/队列/锁 | ❌ 建议使用 sentinel-ha (operator) |
| 高可用自动故障转移 | ❌ 建议使用 sentinel-ha (operator) |

---

## 2. 架构

```
┌──────────────────────────────────┐
│  namespace: redis-deployment     │
│                                  │
│  Deployment: redis-standalone    │
│  └── Pod: redis-standalone-xxx   │
│      ├── redis:7.0-alpine        │
│      └── PVC: redis-data (RWO)   │
│                                  │
│  Service: redis-standalone       │
│  └── ClusterIP: 6379             │
│  └── NodePort: 30005             │
│                                  │
│  PDB: redis-standalone           │
│  └── maxUnavailable: 1           │
└──────────────────────────────────┘
```

### 核心组件

| 组件 | 数量 | 说明 |
|------|------|------|
| Pod | 1（固定） | 单实例 Redis，不可扩缩 |
| PVC | 1 | RWO 模式，绑定到单个 Pod |
| Service | 1 | ClusterIP + NodePort 30005 |
| PDB | 1 | 允许自愿调度中断 |

### 为什么只有 1 个副本？

Redis 是**有状态服务**，数据目录 (`/data`) 存储 AOF/RDB 文件：

- **RWO PVC**：同一时刻只能一个 Pod 挂载读写，保证数据一致性
- **扩缩容限制**：`replicas` 必须固定为 1。如果改为 2+，第二个 Pod 会因为 PVC 已被占用而卡在 Pending（RWO 特性）
- **扩容不会造成数据损坏**：RWO 本身阻止了多 Pod 同时写入，Pod 只会卡住，不丢数据

---

## 3. 与 Operator 方案对比

| 特性 | Deployment（本方案） | Operator standalone | Operator sentinel-ha |
|------|--------------------|--------------------|---------------------|
| **节点断电自动迁移** | ✅ 自动 | ❌ 手动 | ❌ 手动 |
| **K8s 版本要求** | ✅ 1.19+ | ✅ 1.19+ | ✅ 1.19+ |
| **误扩缩容保护** | ⚠️ RWO PVC 阻止（卡 Pending） | ✅ Operator 限制 | ✅ Operator 限制 |
| **数据持久化** | ✅ 同 (AOF+RDB) | ✅ 同 | ✅ 同 |
| **高可用（主从/哨兵）** | ❌ 无 | ❌ 无 | ✅ 自动故障转移 |
| **密码认证** | ✅ Secret 挂载 | ✅ Secret 注入 | ✅ Secret 注入 |
| **监控指标** | ⚠️ 需额外部署 exporter | ✅ 内置 exporter | ✅ 内置 exporter |
| **存储** | RWO（推荐），RWX 也可 | RWO | RWO |
| **Pod 标识** | 不固定（无状态标识） | 固定（redis-0） | 固定（redis-replication-0） |

### 关键局限

1. **无内置 metric exporter**：operator 方案自动部署了 redis-exporter sidecar，本方案需要自行额外部署（或在 Deployment 里添加 sidecar）
2. **Pod 名不固定**：重建后名称变化（如 `redis-standalone-7d8f9c`），依赖 hostname 的场景需要适配
3. **仅 standalone**：不支持主从复制，不做 sentinel 高可用

---

## 4. PVC 模式说明：RWO vs RWX

> **对于单实例 Redis，必须使用 RWO（ReadWriteOnce）。**

### RWO 在这里为什么合理

| 前提 | 说明 |
|------|------|
| 仅 1 个副本 | 不存在多 Pod 争用问题 |
| 节点迁移时 PVC 解绑 | 旧 Pod 进入 Terminating → 卷控制器强制解绑 → 新 Pod 在健康节点挂载同一块 PVC |
| **不可扩缩** | replicas=1 固定，RWO 天然防止意外扩到多副本 |

### 为什么不推荐 RWX

- 如果手工把 replicas 改成 2+，RWX 会让两个 Redis 实例同时写入同一数据目录 → AOF/RDB 文件损坏
- RWO 则安全拒绝：第二个 Pod 卡在 Pending，不会造成数据损坏

### NFS 支持 RWO

NFS Provisioner 同时支持 RWO 和 RWX。指定 `accessModes: [ReadWriteOnce]` 即可——NFS 后端在服务端做客户端排他控制。

---

## 5. 节点故障恢复流程

```
时间轴：

  t=0    节点断电
          ↓
  t=40s  Node NotReady（默认 node-monitor-grace-period）
          ↓
  t+40s  Pod 从 Running 变为 Terminating/Unknown
          ↓
  t+60s  ReplicaSet 检测到 Terminating Pod，创建新 Pod（立即！）
          ↓
  t+70s  新 Pod 调度到健康节点，挂载同一 PVC
          ↓
  t+80s  Redis 启动完成，加载 AOF/RDB，开始服务
          ↓
  t+90s  ✅ 恢复（约 90 秒，含 node-eviction-timeout 等待）
```

**可通过调优 kube-controller-manager 参数缩短恢复时间：**

```bash
# 在 k3s server 启动参数中添加（视版本支持情况）
--kube-controller-manager-arg="node-monitor-grace-period=10s"
--kube-controller-manager-arg="node-eviction-timeout=30s"
```

⚠️ 注意：`node-eviction-timeout` 在 K8s 1.25+ 被移除，如果你的生产集群是低版本（如 1.19）则仍然可用。

---

## 6. 快速开始

```bash
# 创建 namespace + Secret + PVC + Deployment + Service + PDB
./install.sh

# 验证
kubectl get pods -n redis-deployment -w
redis-cli -h <节点IP> -p 30005 ping
redis-cli -h <节点IP> -p 30005 -a 'redis@czw' SET foo bar
redis-cli -h <节点IP> -p 30005 -a 'redis@czw' GET foo
```

## 7. 卸载

```bash
# 删除全部资源
./uninstall.sh
```

---

## 8. 已知问题与风险

1. **AOF/RDB 文件一致性**：如果节点突然断电，新 Pod 在健康节点启动时 Redis 会做 AOF 文件校验/修复（`redis-check-aof`），不影响正常运行。极端情况下可能丢失 1 秒数据（AOF everysec 配置）。

2. **PVC 解绑延时**：节点彻底失联后，Kubernetes 卷控制器需要等待 `node-eviction-timeout` 才会强制解绑 PVC。如果调优后约 60-90 秒，不调优约 5-6 分钟。

3. **不适用于主从复制**：Deployment 模式不支持 `REPLICAOF` 等主从拓扑管理。如需主从/哨兵，请使用 operator sentinel-ha。

4. **Prometheus 监控**：默认不包含 redis-exporter，如需监控请在 Deployment 中添加 exporter sidecar 容器。

---

## 9. 与 operator 方案并存

两者使用不同的 namespace 和端口，可同时部署：

| 方案 | Namespace | NodePort | 路径 |
|------|-----------|----------|------|
| Deployment standalone（本方案） | `redis-deployment` | 30005 | `deployment/` |
| Operator standalone | `redis` | 30003 | `operator/standalone/` |
| Operator sentinel-ha | `redis` | 30004 | `operator/sentinel-ha/` |
| Operator cluster | `redis` | 不暴露 | `operator/cluster/` |

---

## 10. 总结

**Deployment 方案不是替代 operator，而是一种针对性解法**：

- 它解决的是**"节点断电后 Pod 自动迁移"**这一具体问题
- 它适用于**非关键的单实例 Redis 场景**
- 它坦诚保留了 RWO 的安全边界——即使误扩缩容也不会损坏数据
- 对于核心生产数据，仍然推荐 operator sentinel-ha + 手动干预

> "Deployment 模式用 Kubernetes 的原生能力（ReplicaSet 过滤 Terminating Pod），
>  以牺牲高可用和监控为代价，换来了节点故障的自动迁移能力。"