#!/bin/bash
# Redis 卸载脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPERATOR_NS="redis-operator"
REDIS_NS="redis"

echo "🗑️  步骤 1/2：删除 Redis 实例 CR..."

# 删除 CR（触发 operator 清理 StatefulSet + PVC）
kubectl delete -f "$SCRIPT_DIR/operator/" 2>/dev/null || true
kubectl delete namespace "$REDIS_NS" --ignore-not-found 2>/dev/null || true

echo ""
echo "🗑️  步骤 2/2：卸载 redis-operator..."
helm uninstall redis-operator --namespace "$OPERATOR_NS" 2>/dev/null || true
kubectl delete namespace "$OPERATOR_NS" --ignore-not-found 2>/dev/null || true

echo ""
echo "⚠️  CRD 未自动删除。如需清理："
echo "   kubectl delete crd -l app.kubernetes.io/managed-by=redis-operator"
echo ""
echo "✅ 卸载完成"
