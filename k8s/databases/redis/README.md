# Redis 7

Redis deployment on Kubernetes — supporting 3 deployment strategies.

## Versions

| Component | Version |
|-----------|---------|
| Redis Image | redis:7.4 |
| Redis Operator (OT-OP) | 0.24.0 |
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

#### Standalone via OT-OP

```bash
kubectl apply -f operator/standalone/
```

#### Sentinel HA

```bash
kubectl apply -f operator/sentinel-ha/
```

#### Redis Cluster

```bash
kubectl apply -f operator/cluster/
```

## Structure

| Path | Description |
|------|-------------|
| `manifests/` | Standalone Redis — Secret, PVC, Deployment, Service |
| `helm/` | Custom Helm chart with configurable values |
| `operator/` | 3 operator patterns — standalone, sentinel HA, cluster |

## Notes

`helm/values.yaml` contains the default configuration. Override via `--set` or custom values file.
