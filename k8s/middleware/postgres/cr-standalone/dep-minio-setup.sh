#!/bin/bash
# setup.sh — PostgreSQL 在 MinIO 上创建备份桶和用户
# 由 install.sh 自动调用，也可独立执行（用于单独重配备份）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MINIO_POD=$(kubectl -n minio get pod -l v1.min.io/tenant=minio -o name 2>/dev/null | head -1)
if [ -z "$MINIO_POD" ]; then
  echo "⚠️  MinIO 不可用，跳过 S3 备份配置"
  exit 0
fi

echo ">> 配置 MinIO S3 备份 ..."

# mc 别名
kubectl -n minio exec "$MINIO_POD" -c minio -- mc alias set local http://localhost:9000 minioadmin minioadmin 2>/dev/null || true

# 桶（幂等）
kubectl -n minio exec "$MINIO_POD" -c minio -- mc mb local/postgres-backup --ignore-existing 2>/dev/null || true
echo "   ✅ 备份桶 postgres-backup 已就绪"

# Policy
kubectl -n minio exec -i "$MINIO_POD" -c minio -- sh -c 'cat > /tmp/pg-backup-policy.json' < "$SCRIPT_DIR/dep-minio-backup-policy.json" 2>/dev/null
kubectl -n minio exec "$MINIO_POD" -c minio -- mc admin policy create local pg-backup /tmp/pg-backup-policy.json 2>/dev/null || true
kubectl -n minio exec "$MINIO_POD" -c minio -- mc admin user add local pg-backup Z6rX9pLm8kQw4nSv 2>/dev/null || true
kubectl -n minio exec "$MINIO_POD" -c minio -- mc admin policy attach local pg-backup --user=pg-backup 2>/dev/null || true
echo "   ✅ MinIO 备份用户已就绪"
