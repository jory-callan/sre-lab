#!/bin/bash
# Helm 模式 Redis 卸载脚本
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
NAMESPACE="${1:-redis-deployment}"
RELEASE="${2:-redis-standalone}"

echo "🗑️  卸载 Redis (Helm chart)"
echo "   Release:  $RELEASE"
echo "   Namespace: $NAMESPACE"
echo ""

helm uninstall "$RELEASE" --namespace "$NAMESPACE" 2>/dev/null || true

# 删除 PVC（helm 不自动删除 PVC）
kubectl delete pvc -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE" --ignore-not-found 2>/dev/null || true

echo "✅ 卸载完成"