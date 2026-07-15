#!/bin/bash
# install.sh — Kite 测试实例
# Usage: bash install.sh [install|uninstall|purge]
#   install    部署服务（幂等）
#   uninstall  卸载服务，保留 PVC / 数据
#   purge      完全卸载干净
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== 配置区 =====
NAME="kite"
NAMESPACE="kite"
CHART="$SCRIPT_DIR/../chart"
VALUES="$SCRIPT_DIR/values.yaml"
# ===================

install() {
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  helm upgrade --install "$NAME" "$CHART" \
    --namespace "$NAMESPACE" \
    --values "$VALUES" \
    --timeout 5m --wait
}

uninstall() {
  helm uninstall "$NAME" --namespace "$NAMESPACE"
}

purge() {
  helm uninstall "$NAME" --namespace "$NAMESPACE" 2>/dev/null || true
  kubectl delete namespace "$NAMESPACE" --ignore-not-found
}

case "${1:-install}" in
  install) install ;;
  uninstall) uninstall ;;
  purge) purge ;;
  *) echo "Usage: $0 [install|uninstall|purge]"; exit 1 ;;
esac
