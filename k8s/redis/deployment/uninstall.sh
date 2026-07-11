#!/bin/bash
# Deployment 模式 Redis 卸载脚本
#
# 用法:
#   ./uninstall.sh             # 删除全部资源

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
MANIFESTS="$SCRIPT_DIR/manifests"
NAMESPACE="redis-deployment"

echo "🗑️  卸载 Deployment 模式 Redis (standalone)"
echo ""

# 先标记未知
echo "🔄 删除 Deployment（触发优雅停止）..."
kubectl delete -f "$MANIFESTS/02-deployment.yaml" --ignore-not-found --wait=false 2>/dev/null

echo "⏳ 等待 Pod 停止（最多 30s）..."
kubectl wait --for=delete pod -l app=redis-standalone -n "$NAMESPACE" --timeout=30s 2>/dev/null || true

# 删除其他资源
echo "🗑️  删除 Service..."
kubectl delete -f "$MANIFESTS/03-service.yaml" --ignore-not-found 2>/dev/null

echo "🗑️  删除 PVC（含数据）..."
kubectl delete -f "$MANIFESTS/01-pvc.yaml" --ignore-not-found 2>/dev/null

echo "🗑️  删除 PDB..."
kubectl delete -f "$MANIFESTS/04-pdb.yaml" --ignore-not-found 2>/dev/null

echo "🗑️  删除 Secret..."
kubectl delete -f "$MANIFESTS/00-secret.yaml" --ignore-not-found 2>/dev/null

echo "🗑️  删除 namespace..."
kubectl delete namespace "$NAMESPACE" --ignore-not-found 2>/dev/null || true

echo ""
echo "✅ 卸载完成"