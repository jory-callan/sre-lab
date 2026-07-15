#!/bin/bash
# install.sh — Redis Operator (spotahome/redisoperator)
# Usage: bash install.sh [install|uninstall]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== 配置区 =====
NAME="redisoperator"
NAMESPACE="operators"
# ==================

install() {
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -f "$SCRIPT_DIR/00-operator.yaml" --namespace "$NAMESPACE"
  echo "✅ Redis Operator 部署完成"
}

uninstall() {
  kubectl delete -f "$SCRIPT_DIR/00-operator.yaml" --namespace "$NAMESPACE" 2>/dev/null || true
  echo "✅ Redis Operator 已卸载"
}

case "${1:-install}" in
  install) install ;;
  uninstall) uninstall ;;
  *) echo "Usage: $0 [install|uninstall]"; exit 1 ;;
esac
