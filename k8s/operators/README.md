# Operators — K8s 集群 Operator 统一部署目录

所有 Operator 程序及其 CRD 统一安装在 `operators` 命名空间，实例 CR 放在各自业务命名空间。

## 目录

| 目录 | Operator | 实例命名空间 |
|------|----------|-------------|
| `cnpg/` | CloudNativePG (PostgreSQL) | `postgres` |
| `redis/` | Redis Operator | (待定) |
| `minio/` | MinIO Operator | (待定) |
| `mysql/` | MySQL Operator | (待定) |

## 安装

```bash
# 先创建命名空间
kubectl create namespace operators --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f resourcequota.yaml

# 安装具体 operator
bash cnpg/install.sh
```
