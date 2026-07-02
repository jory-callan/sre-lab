# 生产就绪指南 — v0.9.0 能力边界与配置

> 本文档对标"生产系统 7 层稳定性模型"，逐一说明 v0.9.0 能做什么、不能做什么、以及补位方案。

## 7 层生产稳定性模型总览

```
┌────────────────────────────────────────────┐
│  ⑦ 退出层 — terminationGracePeriod         │  ← 30s 默认，可接受
├────────────────────────────────────────────┤
│  ⑥ 调度层 — nodeSelector / tolerations     │  ✅ CRD 支持
├────────────────────────────────────────────┤
│  ⑤ 健康层 — probes                         │  ✅ controller 自动生成*
├────────────────────────────────────────────┤
│  ④ 分布层 — affinity / topologySpread      │  ⚠️ 仅 anti-affinity，无 spread
├────────────────────────────────────────────┤
│  ③ 保护层 — PDB                            │  ❌ K8s 1.19 不支持
├────────────────────────────────────────────┤
│  ② 扩缩容 — HPA                            │  ❌ STS 不适用（手动 scale）
├────────────────────────────────────────────┤
│  ① 资源层 — request / limit                │  ✅ CRD 支持
└────────────────────────────────────────────┘
```

---

## ① 资源层 — ✅ 支持

| 字段 | v0.9.0 | 生产建议 |
|------|--------|---------|
| `requests.cpu` | ✅ 传递到 container | 500m~1，Redis 单线程，多 CPU 意义不大 |
| `requests.memory` | ✅ 传递到 container | 按数据集估算，留 20% 余量 |
| `limits.memory` | ✅ 传递到 container | **必须设**，防止 OOM Killer |
| `limits.cpu` | ✅ 传递到 container | **建议不设**，CPU throttle 降低 Redis 性能 |
| exporter resources | ✅ 传递到 container | 64Mi/128Mi 足够 |

**⚠️ 注意**：Redis 的 `maxmemory` 不会自动跟随 K8s 资源限制。需要手动在 `redisConfig` 或 entrypoint 脚本里将 `maxmemory` 设为 memory limit 的 80%。该 operator 的定制镜像做了这件事，**所以必须使用 `quay.io/opstree/redis` 镜像**，不能用官方 `redis:7`。

---

## ② 扩缩容 — ⚠️ 不适用（架构限制）

StatefulSet 不能直接用 HPA（水平 Pod 自动扩缩容），因为：

- **单机 Redis** — 不能水平扩，只能垂直扩（加大 resources）
- **Redis Cluster** — 扩缩容 = 加/减分片，需要 operator 支持。v0.9.0 **不支持动态扩缩容**（v0.15.0+ 才支持）

**补位方案**：
```
单机: 垂直扩容 → 修改 resources → 滚动更新
集群: 创建新 CR 重建（不推荐在 1.19 上生产跑集群）
```

---

## ③ 保护层 — ⚠️ 可手动补（operator 不会自动创建）

**PDB（PodDisruptionBudget）** 是独立 K8s 资源，不是 Pod 的一部分。v0.9.0 不会创建 PDB，但 **operator 也不管 PDB**——你手动创建之后 operator 不会碰它。

K8s 1.19 有 `policy/v1beta1`，可以正常使用：

```bash
kubectl apply -f - <<EOF
apiVersion: policy/v1beta1
kind: PodDisruptionBudget
metadata:
  name: redis-standalone-pdb
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: redis-standalone
EOF
```

**注意**：如果 operator 重建 Pod 导致 label 变化，PDB 的 selector 可能需要同步更新，这是手动维护的成本。

---

## ④ 分布层 — ⚠️ 部分支持

| 特性 | v0.9.0 CRD | 示例中已启用 |
|------|-----------|------------|
| `affinity.nodeAffinity` | ✅ | 否（可选配置） |
| `affinity.podAntiAffinity` | ✅ | **是** |
| `affinity.podAffinity` | ✅ | 否（很少需要） |
| `topologySpreadConstraints` | ❌ 不支持 | 无法配置 |
| `nodeSelector` | ✅ | 否（可选） |
| `tolerations` | ✅ | 否（可选） |

**缺少 `topologySpreadConstraints`** 是 v0.9.0 的一个实际缺陷：
- 只有一个反亲和（"不要在一起"），没有"均匀分布到所有 node"的能力
- 3 节点集群 + 6 个 Pod 时，可能 3 个节点各跑 2 个，也可能 2 个节点各跑 3 个

---

## ⑤ 健康层 — ✅ 支持（但有细节差异）

### Redis 主容器

Controller 自动生成 liveness + readiness probe：

```go
// getProbeInfo() 实际代码
Probe{
    InitialDelaySeconds: 15,    // Pod 启动 15s 后开始探测
    PeriodSeconds:       15,    // 每 15s 探测一次
    FailureThreshold:    5,     // 连续 5 次失败 = 不健康
    TimeoutSeconds:      5,     // 单次探测超时 5s
    Handler: ExecAction{
        Command: ["bash", "/usr/bin/healthcheck.sh"],
    },
}
```

这是合理的生产配置。**总判定时间 = 15 + 15×5 = 90s**，即一个 Redis 挂掉 90s 后才会被重启。

### Redis Exporter 容器

**❌ 没有 probes**，这是 v0.9.0 的一个已知缺陷。exporter 挂了不会自动恢复。

**补位方案**：无法通过 CR 修复，需升级 operator 版本（v0.15.0+ 才有），或在 K8s 层面加存活探针：

```bash
# 可以在 Pod annotation 加 kube-proxy 级别检测
# 但无法注入到 sidecar 内部
```

实际影响：exporter 挂了不会影响 Redis 本身，只是监控数据空了。大多数情况下能接受。

---

## ⑥ 调度层 — ✅ 支持

| 字段 | 说明 |
|------|------|
| `nodeSelector` | 固定调度到带某 label 的节点 |
| `tolerations` | 容忍节点 taint |
| `priorityClassName` | 设置 PriorityClass，保障高优先级 Pod 不被驱逐 |

所有这些字段都通过 CRD 传递到 PodSpec。

---

## ⑦ 退出层 — ⚠️ 依赖 K8s 默认值

v0.9.0 的 controller **没有设置** `terminationGracePeriodSeconds`。

K8s 默认值是 **30s**，对 Redis 来说：
- 正常情况 Redis 进程 SIGTERM 后几毫秒就退出了
- 如果有慢查询正在执行，30s 足够完成
- `redis-cli SHUTDOWN` 会在 30s 内完成持久化

**结论：默认 30s 对 Redis 是合理的，不是问题。**

---

## 生产环境分级评估

| 层级 | 项目 | 你的 1.19 集群 | 如果升级到 1.21+ |
|------|------|---------------|-----------------|
| ✅ 可做 | resources | ✅ | ✅ |
| ✅ 可做 | probes（主容器） | ✅（自动） | ✅（自动） |
| ✅ 可做 | anti-affinity | ✅（示例已启用） | ✅ |
| ✅ 可做 | securityContext | ✅（示例已启用） | ✅ |
| ✅ 可做 | exporter 监控 | ✅ | ✅ |
| ✅ 可做 | 密码认证 | ✅ redisSecret | ✅ |
| ⚠️ 可做但需手动 | PDB | ⚠️ 手动创建 v1beta1 | ✅ operator 自动 |
| ⚠️ 可接受 | terminationGracePeriod | ✅ 默认 30s | ✅ |
| ⚠️ 可接受 | exporter 无 probe | ⚠️ 不影响 Redis | v0.15.0+ 修复 |
| ❌ 不支持 | topologySpreadConstraints | ❌ | v0.19.0+ |
| ❌ 不支持 | cluster 动态扩缩 | ❌ | v0.15.0+ |
| ❌ 不支持 | TLS | ❌ | v0.10.0+ |

---

## 最终判断：生产可用吗？

**单机 Redis — ✅ 生产就绪**。清单：

- [x] 资源限制 — memory limit + request
- [x] 健康检查 — liveness + readiness
- [x] 反亲和 — podAntiAffinity
- [x] 数据持久化 — PVC
- [x] 安全上下文 — securityContext
- [x] 监控 — exporter + Prometheus ServiceMonitor
- [x] 备份 — CronJob（RDB）
- [x] 密码认证 — redisSecret
- [x] **PDB** — ⚠️ 手动创建 policy/v1beta1 即可（附 PDB 模板）

唯一缺少的 PDB 在 1.19 上无法实现。如果接受"维护窗口期手动停服"，这个方案可用。

**Redis Cluster — ⚠️ 生产有限**。高风险点：
1. K8s 1.19 不支持 `topologySpreadConstraints`，6 个 Pod 可能分布不均匀
2. 无 PDB，`kubectl drain node` 会一次驱逐多个 Pod
3. 不支持动态扩缩容（但初始创建没问题）
4. 若 cluster 节点 IP 变化，v0.9.0 的 cluster 恢复逻辑不如新版成熟

建议：**单机用 v0.9.0 上生产，Cluster 只在开发/测试环境用**。等 K8s 升级到 1.21+ 后统一用 v0.25.0。
