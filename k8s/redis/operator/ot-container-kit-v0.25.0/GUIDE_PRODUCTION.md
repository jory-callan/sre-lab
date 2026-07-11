# 生产就绪指南 — v0.25.0

> **7 层生产稳定性模型全部支持**，无关键缺口。
> 要求 K8s 1.21+。

## 7 层模型评估

| # | 层级 | v0.25.0 | 管理方式 | 说明 |
|---|------|---------|---------|------|
| ① | **资源层** — request/limit | ✅ 原生支持 | CR 字段 | memory limit 必须设 |
| ② | **扩缩容** — HPA | ⚠️ 单机不可水平扩 | 垂直改 resources | Cluster 可手动扩 clusterSize |
| ③ | **保护层** — PDB | ✅ **CRD 内置** | `spec.pdb` | 自动创建/管理 PDB |
| ④ | **分布层** — anti-affinity | ✅ 原生支持 | `spec.affinity` | v0.25.0 新增 `topologySpreadConstraints` |
| ⑤ | **健康层** — probes | ✅ **exporter 也有 probe** | controller 自动 | exporter 无遗漏 |
| ⑥ | **调度层** — tolerations | ✅ 原生支持 | CR 字段 | nodeSelector + tolerations |
| ⑦ | **退出层** — graceful shutdown | ✅ 默认 30s | K8s 默认值 | Redis 适用 |

## 关键生产特性详解

### PDB — 自动管理

v0.25.0 的 CRD 内置了 PDB 支持，无需手动创建：

```yaml
spec:
  pdb:
    enabled: true
    minAvailable: 2
    # maxUnavailable: 1        # 二选一
```

Operator 会自动创建/更新/删除对应的 PodDisruptionBudget 资源。

### topologySpreadConstraints

v0.25.0 新增支持，可以在多个维度均匀分布 Pod：

```yaml
spec:
  topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app: redis-standalone
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule
```

### TLS — 生产安全

v0.25.0 支持 TLS（v0.10.0+ 引入）：

```yaml
spec:
  TLS:
    ca: ca-cert
    cert: tls-cert
    key: tls-key
```

### 集群动态扩缩

v0.25.0 支持修改 `clusterSize` 后自动 rebalance：

```yaml
spec:
  clusterSize: 5   # 从 3 改为 5 → 自动扩分片
```

### 生产最小配置模板

```yaml
apiVersion: redis.redis.opstreelabs.in/v1beta2
kind: Redis
metadata:
  name: redis-standalone
spec:
  podSecurityContext:
    runAsUser: 1000
    fsGroup: 1000
  kubernetesConfig:
    image: quay.io/opstree/redis:latest
    resources:
      requests:
        cpu: 500m
        memory: 512Mi
      limits:
        memory: 1Gi
    redisSecret:
      name: redis-secret
      key: password
  redisExporter:
    enabled: true
    image: quay.io/opstree/redis-exporter:latest
  storage:
    volumeClaimTemplate:
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 10Gi
  pdb:
    enabled: true
    minAvailable: 1
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: app
              operator: In
              values:
              - redis-standalone
          topologyKey: kubernetes.io/hostname
```

### 最终判断

**全部模式（单机/主从/集群/Sentinel）— ✅ 生产就绪**。

- [x] 资源限制 — memory limit + request
- [x] 健康检查 — liveness + readiness（含 exporter）
- [x] 反亲和 — podAntiAffinity
- [x] 拓扑分布 — topologySpreadConstraints
- [x] 保护层 — PDB 自动管理
- [x] 数据持久化 — PVC
- [x] 安全上下文 — podSecurityContext
- [x] 监控 — exporter + ServiceMonitor
- [x] 备份 — CronJob RDB
- [x] 密码认证 — redisSecret
- [x] TLS（可选）
- [x] 集群动态扩缩（Cluster 模式）
