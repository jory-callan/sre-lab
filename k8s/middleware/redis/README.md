# Redis

Redis deployment on Kubernetes — supporting 3 deployment strategies.

## Versions

| Component | Version |
|-----------|---------|
| Redis Image | redis:7.4 |
| Redis Operator (OT-OP) | **v0.25.0** (latest 1.21+) / **v0.9.0** (1.19 兼容) |
| Redis Operator (Spotahome) | v1.1.1 |

## Deploy

### Standalone (manifests)

```bash
kubectl apply -f manifests/
```

### Custom Helm Chart

```bash
helm upgrade --install redis helm/
```

### Operator (Production)

| 目录 | K8s 要求 | 适用 |
|------|---------|------|
| `operator/ot-container-kit-v0.25.0/` | **1.21+** | 新集群，推荐（功能最全） |
| `operator/ot-container-kit-v0.9.0/` | 1.19+ | 旧集群，仅单机+集群 |
| `operator/standalone/` | 1.21+ | 单机 CR（v1beta2） |
| `operator/cluster/` | 1.21+ | 集群 CR（v1beta2） |
| `operator/sentinel-ha/` | 1.21+ | Sentinel HA（需 replication） |
| `operator/spotahome/` | 1.19+ | 另一种 operator |

#### v0.25.0（推荐 — K8s 1.21+）

```bash
kubectl apply -f operator/ot-container-kit-v0.25.0/00-namespace.yaml
kubectl apply -f operator/ot-container-kit-v0.25.0/crds/
kubectl apply -f operator/ot-container-kit-v0.25.0/rbac/
kubectl apply -f operator/ot-container-kit-v0.25.0/30-deployment.yaml
```

或用 Helm：

```bash
helm upgrade --install redis-operator operator/ot-container-kit-v0.25.0/helm/ \
  --set standalone.enabled=true \
  --set cluster.enabled=true
```

详见 [operator/ot-container-kit-v0.25.0/README.md](./operator/ot-container-kit-v0.25.0/README.md)

#### v0.9.0（K8s 1.19 兼容版）

```bash
kubectl apply -f operator/ot-container-kit-v0.9.0/00-namespace.yaml
kubectl apply -f operator/ot-container-kit-v0.9.0/crds/
kubectl apply -f operator/ot-container-kit-v0.9.0/rbac/
kubectl apply -f operator/ot-container-kit-v0.9.0/30-deployment.yaml
```

详见 [operator/ot-container-kit-v0.9.0/README.md](./operator/ot-container-kit-v0.9.0/README.md)

## Structure

| Path | Description |
|------|-------------|
| `manifests/` | Standalone Redis — Secret, PVC, Deployment, Service |
| `helm/` | Custom Helm chart with configurable values |
| `operator/ot-container-kit-v0.25.0/` | **当前推荐** — 完整 Helm + 4 CRDs + 生产指南 |
| `operator/ot-container-kit-v0.9.0/` | K8s 1.19 兼容版 — 完整 Helm + 2 CRDs + 生产指南 |
| `operator/standalone/` | 单机 CR（v1beta2） |
| `operator/cluster/` | 集群 CR（v1beta2） |
| `operator/sentinel-ha/` | Sentinel HA CR（v1beta2） |
| `operator/spotahome/` | spotahome/redis-operator 方案 |
