# OT-Container-KIT/redis-operator v0.25.0

> 最新稳定版 — 支持 Redis / RedisCluster / RedisReplication / RedisSentinel 四种 CRD
> 要求 **Kubernetes 1.21+**（使用 `policy/v1`、`admissionregistration.k8s.io/v1` 等 API）

## 文档索引

| 文档 | 说明 |
|------|------|
| **[GUIDE_PRODUCTION.md](./GUIDE_PRODUCTION.md)** | 生产就绪评估（7 层模型全支持） |
| **[GUIDE_MONITORING.md](./GUIDE_MONITORING.md)** | 完整监控方案 |
| **[CHECKLIST_MONITORING.md](./CHECKLIST_MONITORING.md)** | 指标/告警速查 |
| `README.md`（本文件） | 快速部署 |

## 部署

```bash
# 方式一：Kubectl
kubectl apply -f 00-namespace.yaml
kubectl apply -f crds/
kubectl apply -f rbac/
kubectl apply -f 30-deployment.yaml

# 创建实例
kubectl apply -f 40-redis-cr-standalone.yaml
kubectl apply -f 41-rediscluster-cr.yaml
# kubectl apply -f 42-redisreplication-cr.yaml
# kubectl apply -f 43-redissentinel-cr.yaml

# 方式二：Helm（推荐）
helm upgrade --install redis-operator ./helm/ \
  --set standalone.enabled=true
```

## 文件清单

| 文件 | 说明 |
|------|------|
| `00-namespace.yaml` | Namespace |
| `crds/` | 4 个 CRD（Redis/Cluster/Replication/Sentinel） |
| `rbac/` | ServiceAccount + ClusterRole + Binding |
| `30-deployment.yaml` | Operator Deployment |
| `40-redis-cr-standalone.yaml` | 单机 Redis（v1beta2）|
| `41-rediscluster-cr.yaml` | 集群 RedisCluster（v1beta2）|
| `42-redisreplication-cr.yaml` | 主从 RedisReplication（v1beta2）|
| `43-redissentinel-cr.yaml` | Sentinel 高可用（v1beta2）|
| `helm/` | Helm Chart（含 values.yaml 全部可配置）|
| `monitoring/` | ServiceMonitor |
| `backup/` | RDB CronJob 备份 |
| `grafana/` | Dashboard 导入说明 |
| `GUIDE_PRODUCTION.md` | 生产就绪评估 |
| `GUIDE_MONITORING.md` | 监控方案 |
| `CHECKLIST_MONITORING.md` | 指标/告警速查 |

## v0.25.0 vs v0.9.0 差异

| 特性 | v0.9.0 | v0.25.0 |
|------|--------|---------|
| K8s 最低版本 | 1.19 | 1.21 |
| CRD API | `v1beta1` | `v1beta2` |
| CRD 数量 | 2 (Redis/Cluster) | 4 (+ Replication/Sentinel) |
| PDB 自动管理 | ❌ 需手动 | ✅ CRD 内置 |
| Sentinel HA | ❌ | ✅ |
| 主从 Replication | ❌ | ✅ |
| TLS | ❌ | ✅ |
| 集群动态扩缩容 | ❌ | ✅ |
| topologySpreadConstraints | ❌ | ✅ |
| exporter probes | ❌ | ✅ |
