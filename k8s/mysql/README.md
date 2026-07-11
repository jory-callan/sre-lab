# MySQL 8.4

MySQL deployment on Kubernetes.

## Versions

| Component | Version |
|-----------|---------|
| MySQL Image | percona/percona-server:8.4.3 |
| Percona Operator | 1.1.0 |

## Deploy

### Standalone (manifests)

```bash
kubectl apply -f manifests/
```

### Production (Operator)

```bash
# Install operator
kubectl apply -f https://raw.githubusercontent.com/percona/percona-server-mysql-operator/v1.1.0/deploy/bundle.yaml

# Apply CR
kubectl apply -f operator/
```

## Structure

| Path | Description |
|------|-------------|
| `manifests/` | Standalone MySQL — ConfigMap, PVC, StatefulSet, Service |
| `operator/` | Percona Operator CR — MySQL cluster, secrets, external service |

## Notes

- `helm/` kept `values-operator.yaml` for reference — operator deployed via raw YAML is simpler
- Password managed via Kubernetes Secret
