#!/bin/bash
# Kite 卸载脚本 - 支持 manifests 或 helm 方式

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 检查参数
MODE="${1:-manifests}"  # 默认 manifests

if [ "$MODE" != "manifests" ] && [ "$MODE" != "helm" ]; then
  echo "❌ 无效参数！用法："
  echo "   $0 [manifests|helm]"
  exit 1
fi

echo "🗑️  卸载 Kite ($MODE 方式)..."

if [ "$MODE" = "manifests" ]; then
  # Manifests 方式
  kubectl delete -f "$SCRIPT_DIR/manifests/ingress.yaml" 2>/dev/null || true
  kubectl delete -f "$SCRIPT_DIR/manifests/service.yaml" 2>/dev/null || true
  kubectl delete -f "$SCRIPT_DIR/manifests/deployment.yaml" 2>/dev/null || true
  kubectl delete -f "$SCRIPT_DIR/manifests/clusterrolebinding.yaml" 2>/dev/null || true
  kubectl delete -f "$SCRIPT_DIR/manifests/serviceaccount.yaml" 2>/dev/null || true
  kubectl delete -f "$SCRIPT_DIR/manifests/namespace.yaml" 2>/dev/null || true
else
  # Helm 方式
  helm uninstall kite -n kite 2>/dev/null || true
  kubectl delete namespace kite 2>/dev/null || true
fi

echo ""
echo "⚠️  PVC 已保留（如存在），如需彻底删除数据请执行："
echo "   kubectl delete pvc -n kite -l app.kubernetes.io/name=kite"
echo "   或：kubectl delete pvc -n kite kite-storage"
echo ""
echo "✅ Kite 卸载完成！"
