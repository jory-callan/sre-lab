#!/bin/bash
# Redis 卸载脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="redis"

echo "🗑️  卸载 Redis..."

# 删除资源（逆向顺序）
kubectl delete -f "$SCRIPT_DIR/manifests/service.yaml" 2>/dev/null || true
kubectl delete -f "$SCRIPT_DIR/manifests/deployment.yaml" 2>/dev/null || true
kubectl delete -f "$SCRIPT_DIR/manifests/pvc.yaml" 2>/dev/null || true
kubectl delete -f "$SCRIPT_DIR/manifests/secret.yaml" 2>/dev/null || true
kubectl delete -f "$SCRIPT_DIR/manifests/namespace.yaml" 2>/dev/null || true

echo ""
echo "⚠️  PVC 已随命名空间删除。如需保留数据请提前备份。"
echo "✅ Redis 卸载完成"
