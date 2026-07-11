# OT-Container-KIT/redis-operator v0.9.0

> 兼容 **Kubernetes 1.19** 的版本，仅用 `apps/v1`、`core/v1`、`rbac/v1` 标准 API
> 无 Webhook / PDB / Admission 依赖

## 适用场景

新集群建议用 `operator/standalone/` 或 `operator/cluster/`（v0.24.0），但如果你的 K8s 版本是 **1.19**，只有 v0.9.0 能跑。

## 文档索引

| 文档 | 说明 | **必读？** |
|------|------|-----------|
| **[GUIDE_PRODUCTION.md](./GUIDE_PRODUCTION.md)** | 生产就绪评估（7层模型 + PDB 手动补充） | ✅ 上生产前必读 |
| **[GUIDE_MONITORING.md](./GUIDE_MONITORING.md)** | 完整监控方案（指标/告警/Grafana） | ✅ 上生产前必读 |
| **[CHECKLIST_MONITORING.md](./CHECKLIST_MONITORING.md)** | 监控指标 + 告警规则 + 巡检命令 速查表 | ✅ 运维必读 |
| `README.md`（本文件） | 快速部署 + 文件清单 | — |

## 部署方式

### 方式一：Kubectl（传统）

```bash
kubectl apply -f 00-namespace.yaml
kubectl apply -f crds/
kubectl apply -f rbac/
kubectl apply -f 30-deployment.yaml

# 创建单机实例
kubectl apply -f 40-redis-cr-standalone.yaml
# 创建集群实例
kubectl apply -f 41-rediscluster-cr.yaml
```

### 方式二：Helm（推荐，更简洁）

```bash
# 部署 Operator + 单机实例
helm upgrade --install redis-operator ./helm/ \
  --set standalone.enabled=true \
  --set image.tag=v0.9.0

# 部署 Operator + 集群实例
helm upgrade --install redis-operator ./helm/ \
  --set cluster.enabled=true

# 全部一起上
helm upgrade --install redis-operator ./helm/ \
  --set standalone.enabled=true \
  --set cluster.enabled=true

# 换镜像
helm upgrade --install redis-operator ./helm/ \
  --set image.tag=v0.25.0 \
  --set redisImage.tag=v7.0.15

# 查看 values 全部可配置项
helm show values ./helm/
```

## 文件清单

| 文件 | 说明 |
|------|------|
| `00-namespace.yaml` | 创建 `redis-operator` namespace |
| `crds/10-redis.yaml` | CRD: Redis（单机） |
| `crds/11-redisclusters.yaml` | CRD: RedisCluster（集群） |
| `rbac/20-serviceaccount.yaml` | ServiceAccount |
| `rbac/21-clusterrole.yaml` | ClusterRole |
| `rbac/22-clusterrolebinding.yaml` | ClusterRoleBinding |
| `30-deployment.yaml` | Operator Deployment |
| `40-redis-cr-standalone.yaml` | **生产 CR** — 单机（已启用 anti-affinity + securityContext） |
| `41-rediscluster-cr.yaml` | **生产 CR** — 集群（已启用 anti-affinity + securityContext） |
| `monitoring/servicemonitor-standalone.yaml` | Prometheus ServiceMonitor（单机） |
| `monitoring/servicemonitor-cluster.yaml` | Prometheus ServiceMonitor（集群） |
| `backup/cronjob.yaml` | RDB 定时备份 CronJob（S3/MinIO） |
| `grafana/README.md` | Dashboard 导入说明 |
| `GUIDE_PRODUCTION.md` | 生产就绪评估（7层模型） |
| `GUIDE_MONITORING.md` | 完整监控方案 |

## 生产就绪摘要

| 层级 | 特性 | 状态 | 文件位置 |
|------|------|------|---------|
| ① 资源层 | CPU/memory request + limit | ✅ CR 已启用 | `40-*.yaml` |
| ② 扩缩容 | HPA | ❌ STS 不适用 | — |
| ③ 保护层 | PDB | ❌ K8s 1.19 不支持 | 见 `GUIDE_PRODUCTION.md` |
| ④ 分布层 | podAntiAffinity | ✅ CR 已启用 | `40-*.yaml` |
| ⑤ 健康层 | liveness/readiness | ✅ controller 自动 | `statefulset.go` |
| ⑥ 调度层 | nodeSelector/tolerations | ⚠️ 可选，按需取消注释 | `40-*.yaml` |
| ⑦ 退出层 | graceful shutdown | ✅ 默认 30s 合理 | K8s 默认值 |
| 监控 | Redis Exporter + ServiceMonitor | ✅ 已集成 | `GUIDE_MONITORING.md` |
| 备份 | RDB CronJob + S3 | ✅ 已提供 | `backup/cronjob.yaml` |

## 与其他版本的差异

| 特性 | v0.9.0 | v0.24.0+ |
|------|--------|----------|
| K8s 兼容 | 1.19+ | 1.21+ |
| CRD API | `v1beta1` | `v1beta2` |
| PDB | ❌ | ✅ |
| Sentinel | ❌ | ✅ |
| RedisReplication | ❌ | ✅ |
| TLS | ❌ | ✅ |
| 集群扩缩容 | ❌ | ✅ |
| topologySpreadConstraints | ❌ | ✅ |
| exporter probes | ❌ | ✅ |
