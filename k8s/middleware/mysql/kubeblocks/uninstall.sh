#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NAMESPACE="mysql"
CLUSTER_NAME="mysql-kb"

echo "=============================="
echo "MySQL Cluster (KubeBlocks) 卸载"
echo "=============================="
echo ""

echo "[1/2] 删除 MySQL Cluster"
kubectl delete cluster/$CLUSTER_NAME -n "$NAMESPACE" --timeout=300s 2>/dev/null || true
echo "       完成"

echo ""
echo "[2/2] 清理 PVC"
kubectl delete pvc -n "$NAMESPACE" -l app.kubernetes.io/instance=$CLUSTER_NAME --timeout=60s 2>/dev/null || true
echo "       完成"

echo ""
echo "MySQL Cluster 已卸载"
echo "注意: 命名空间 $NAMESPACE 保留，不影响其他 MySQL 部署方案"
