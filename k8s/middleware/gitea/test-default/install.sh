#!/bin/bash
# install.sh — Gitea 测试实例
# Usage: bash install.sh [install|uninstall|purge]
#   install    部署服务（幂等）
#   uninstall  卸载服务，保留 PVC / 数据
#   purge      完全卸载干净
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== 配置区 =====
NAME="gitea"
NAMESPACE="gitea"
CHART="$SCRIPT_DIR/../chart"
VALUES="$SCRIPT_DIR/values.yaml"
# ===================

install() {
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  # 标记 Helm ownership，使 chart 中的资源可以接管 namespace
  kubectl label namespace "$NAMESPACE" app.kubernetes.io/managed-by=Helm --overwrite 2>/dev/null || true
  kubectl annotate namespace "$NAMESPACE" meta.helm.sh/release-name="$NAME" --overwrite 2>/dev/null || true
  kubectl annotate namespace "$NAMESPACE" meta.helm.sh/release-namespace="$NAMESPACE" --overwrite 2>/dev/null || true
  # 命名空间配额
  kubectl apply -f "$SCRIPT_DIR/../resourcequota.yaml" 2>/dev/null || true
  helm upgrade --install "$NAME" "$CHART" \
    --namespace "$NAMESPACE" \
    --values "$VALUES" \
    --timeout 10m --wait
}

uninstall() {
  helm uninstall "$NAME" --namespace "$NAMESPACE"
}

purge() {
  helm uninstall "$NAME" --namespace "$NAMESPACE" 2>/dev/null || true
  kubectl delete pvc --namespace "$NAMESPACE" --all --ignore-not-found 2>/dev/null || true
  kubectl delete namespace "$NAMESPACE" --ignore-not-found
}

case "${1:-install}" in
  install) install ;;
  uninstall) uninstall ;;
  purge) purge ;;
  *) echo "Usage: $0 [install|uninstall|purge]"; exit 1 ;;
esac
