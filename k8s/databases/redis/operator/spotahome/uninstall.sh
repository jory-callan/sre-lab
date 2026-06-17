#!/bin/bash
set -euo pipefail

# spotahome/redis-operator 卸载脚本
# 用法: ./uninstall.sh [namespace]
# 默认: namespace=redis-spotahome

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NAMESPACE="${1:-redis-spotahome}"

echo "=============================="
echo "spotahome/redis-operator 卸载"
echo "=============================="
echo "命名空间: $NAMESPACE"
echo ""

# Step 1: 删除 RedisFailover CR（会级联删除所有 Redis + Sentinel Pod、PVC、Service、ConfigMap）
echo "[1/4] 删除 RedisFailover CR..."
kubectl delete -f "$SCRIPT_DIR/01-redisfailover-cr.yaml" --ignore-not-found=true

# Step 2: 等待删除完成
echo "[2/4] 等待资源清理..."
sleep 10

# Step 3: 删除 Operator（RBAC + Deployment）
echo "[3/4] 删除 Operator..."
kubectl delete -f "$SCRIPT_DIR/00-operator.yaml" --ignore-not-found=true

# Step 4: 删除命名空间（会级联删除所有附属资源）
echo "[4/4] 删除命名空间..."
kubectl delete ns "$NAMESPACE" --ignore-not-found=true

echo ""
echo "卸载完成"