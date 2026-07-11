#!/bin/bash
# uninstall.sh — MinIO 对象存储 (MinIO Operator)
# 用法: bash uninstall.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
OPERATOR_NS="minio-operator"
TENANT_NS="minio"

echo ">> 删除 MinIO Tenant ..."
kubectl delete tenant minio -n "$TENANT_NS" --ignore-not-found --wait=true

echo ">> 删除 PVC ..."
kubectl delete pvc -n "$TENANT_NS" --all --ignore-not-found

echo ">> 删除命名空间 $TENANT_NS ..."
kubectl delete namespace "$TENANT_NS" --ignore-not-found --wait=true

echo ">> 卸载 MinIO Operator ..."
helm uninstall minio-operator -n "$OPERATOR_NS" --ignore-not-found --wait

echo ">> 删除命名空间 $OPERATOR_NS ..."
kubectl delete namespace "$OPERATOR_NS" --ignore-not-found --wait=true

echo ""
echo "✅ MinIO 已完全卸载"
