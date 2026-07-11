# CloudNativePG Operator 安装

## 方式一：Helm（推荐）

```bash
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm repo update

# CRD 过大（clusters.yaml 454KB, poolers.yaml 638KB），需要 --include-crds
# 或先手动安装 CRD：
kubectl apply --server-side -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/v1.30.0/config/crd/bases/postgresql.cnpg.io_clusters.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/v1.30.0/config/crd/bases/postgresql.cnpg.io_poolers.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/v1.30.0/config/crd/bases/postgresql.cnpg.io_backups.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/v1.30.0/config/crd/bases/postgresql.cnpg.io_scheduledbackups.yaml

# 安装 Operator
helm upgrade --install cnpg cnpg/cloudnative-pg \
  --namespace cnpg-system \
  --create-namespace \
  --version 0.29.0 \
  --set config.clusterWide=true
```

## 方式二：Helm（离线 chart）

## 验证 Operator 就绪

```bash
# 检查 Pod
kubectl -n cnpg-system get pod -l app.kubernetes.io/name=cloudnative-pg

# 检查 CRDs 是否安装
kubectl get crd | grep cnpg

# 检查 Operator 日志
kubectl -n cnpg-system logs -l app.kubernetes.io/name=cloudnative-pg
```

## 关于 CRD 大小问题

CNPG 的 CRD YAML 文件体积远超 Helm annotations 的 256KB 限制：

| CRD | 大小 |
|------|------|
| `clusters.postgresql.cnpg.io` | 454KB |
| `poolers.postgresql.cnpg.io` | 638KB |
| `backups.postgresql.cnpg.io` | 19KB |

**解决方案：** Helm chart 设置 `includeCRDs: true`，CRD 由 Helm 直接安装
（不走 annotations，不受 256KB 限制）。

## 版本兼容性

| Operator 版本 | CNPG 版本 | PostgreSQL 版本 |
|---------------|-----------|----------------|
| 0.29.0 | 1.30.0 | 16.x, 15.x, 14.x, 13.x |
| 0.28.0 | 1.29.0 | 16.x, 15.x, 14.x, 13.x |

当前测试使用：**Operator v0.29.0 / CNPG 1.30.0 / PostgreSQL 16.4**
