#!/bin/bash
# install.sh — CloudNativePG Operator
# Usage: bash install.sh [install|uninstall]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== 配置区 =====
NAME="cnpg"
NAMESPACE="operators"
CHART="$SCRIPT_DIR/cloudnative-pg-0.28.2.tgz"
VALUES="$SCRIPT_DIR/values.yaml"
# ==================

install() {
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  helm upgrade --install "$NAME" "$CHART" \
    --namespace "$NAMESPACE" \
    --values "$VALUES" \
    --timeout 5m --wait
}

uninstall() {
  helm uninstall "$NAME" --namespace "$NAMESPACE" 2>/dev/null || true
  kubectl delete crd -l app.kubernetes.io/name=cloudnative-pg 2>/dev/null || true
  echo ""
  echo "⚠️  注意：CRD 和实例 PVC 未删除，如需彻底清理："
  echo "   kubectl delete crd -l app.kubernetes.io/name=cloudnative-pg"
  echo "   kubectl delete pvc -n postgres --all"
}

case "${1:-install}" in
  install) install ;;
  uninstall) uninstall ;;
  *) echo "Usage: $0 [install|uninstall]"; exit 1 ;;
esac
