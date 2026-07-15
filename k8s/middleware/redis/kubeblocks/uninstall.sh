#!/bin/bash
# uninstall.sh — Redis Cluster (KubeBlocks) 卸载
# 用法: bash uninstall.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="redis"
CLUSTER_NAME="redis-kb"

echo "=============================="
echo "Redis Cluster (KubeBlocks) 卸载"
echo "=============================="
echo ""

echo "[1/3] 删除 Redis Cluster"
kubectl delete cluster/$CLUSTER_NAME -n "$NAMESPACE" --timeout=300s 2>/dev/null || true
echo "       完成"

echo ""
echo "[2/3] 清理 PVC（去除 finalizer 防止卡住）"
for pvc in $(kubectl get pvc -n "$NAMESPACE" -l app.kubernetes.io/instance="$CLUSTER_NAME" -o name 2>/dev/null); do
  kubectl patch "$pvc" -n "$NAMESPACE" -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
  kubectl delete "$pvc" -n "$NAMESPACE" --force --grace-period=0 2>/dev/null || true
done
echo "       完成"

echo ""
echo "[3/3] 清理 ConfigMap 等残留"
kubectl delete cm -n "$NAMESPACE" -l app.kubernetes.io/instance="$CLUSTER_NAME" --timeout=30s 2>/dev/null || true
echo "       完成"

echo ""
echo "Redis Cluster 已卸载"
echo "注意: 命名空间 $NAMESPACE 保留，不影响其他 Redis 部署方案"