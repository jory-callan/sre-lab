#!/bin/bash
# Kite 安装脚本 - 支持 manifests 或 helm 方式

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 检查参数
MODE="${1:-manifests}"  # 默认 manifests

if [ "$MODE" != "manifests" ] && [ "$MODE" != "helm" ]; then
  echo "❌ 无效参数！用法："
  echo "   $0 [manifests|helm]"
  exit 1
fi

echo "📦 安装 Kite ($MODE 方式)..."

if [ "$MODE" = "manifests" ]; then
  # Manifests 方式
  kubectl apply -f "$SCRIPT_DIR/manifests/namespace.yaml"
  kubectl apply -f "$SCRIPT_DIR/manifests/serviceaccount.yaml"
  kubectl apply -f "$SCRIPT_DIR/manifests/clusterrolebinding.yaml"
  kubectl apply -f "$SCRIPT_DIR/manifests/pvc.yaml"
  kubectl apply -f "$SCRIPT_DIR/manifests/deployment.yaml"
  kubectl apply -f "$SCRIPT_DIR/manifests/service.yaml"
  kubectl apply -f "$SCRIPT_DIR/manifests/ingress.yaml"
else
  # Helm 方式
  helm upgrade --install kite "$SCRIPT_DIR/helm" \
    -n kite --create-namespace \
    -f "$SCRIPT_DIR/helm/values-prod.yaml"
fi

echo ""
echo "✅ Kite 安装完成！"
echo ""
echo "📝 访问地址：http://kite.czw-sre.internal"
echo "   （请先配置本地 hosts：192.168.5.240 kite.czw-sre.internal）"
echo ""
echo "🔍 查看状态："
echo "   kubectl get pods -n kite"
echo "   kubectl get ingress -n kite"
