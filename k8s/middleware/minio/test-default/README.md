# MinIO Tenant — 测试实例（生产使用）

对象存储服务，Operator v5.0.18 + MinIO RELEASE.2025-04-22（最后一个完整 WebUI）。

## 版本

| 组件 | 版本 |
|------|------|
| MinIO Operator | v5.0.18 |
| MinIO 镜像 | RELEASE.2025-04-22T22-12-26Z |

## 访问

| 位置 | 服务 | 地址 |
|------|------|------|
| 集群外部 | S3 API | https://minio-api.czw-sre.internal |
| 集群外部 | Console | https://minio.czw-sre.internal |
| 集群内部 | S3 API | http://minio.minio.svc:80 |
| 集群内部 | Console | http://minio-console.minio.svc:9090 |

## 凭证

| 账号 | 类型 | 获取方式 |
|------|------|---------|
| minioadmin / minioadmin | root | 见 secret-root.yaml |
| svc-poweruser | 服务账号 | `kubectl -n minio get secret svc-poweruser` |
| svc-private | 服务账号 | `kubectl -n minio get secret svc-private` |

## 验证

```bash
kubectl -n minio get pods
# 或用 mc
kubectl -n minio exec deploy/minio-pool-0-0 -c minio -- mc admin info local
```
