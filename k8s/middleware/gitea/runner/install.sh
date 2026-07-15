#!/bin/bash
# install.sh — Gitea Actions Runner
# Usage: bash install.sh [install|uninstall|purge]
#   install    部署 runner（幂等）
#   uninstall  卸载 runner，保留 PVC / 数据
#   purge      完全卸载干净
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== 配置区 =====
NAME="gitea-runner"
VALUES="$SCRIPT_DIR/chart/values.yaml"
# ===================

install() {
  kubectl create namespace gitea-runner --dry-run=client -o yaml | kubectl apply -f -
  kubectl label namespace gitea-runner app.kubernetes.io/managed-by=Helm --overwrite 2>/dev/null || true
  kubectl annotate namespace gitea-runner meta.helm.sh/release-name="$NAME" --overwrite 2>/dev/null || true
  kubectl annotate namespace gitea-runner meta.helm.sh/release-namespace=gitea-runner --overwrite 2>/dev/null || true
  # 可选：集群级 ci-deployer SA
  kubectl apply -f "$SCRIPT_DIR/common/ci-deployer.yaml" 2>/dev/null || true
  helm upgrade --install "$NAME" "$SCRIPT_DIR/chart" \
    --namespace gitea-runner \
    --values "$VALUES" \
    --timeout 3m --wait
}

uninstall() {
  helm uninstall "$NAME" --namespace gitea-runner
}

purge() {
  helm uninstall "$NAME" --namespace gitea-runner 2>/dev/null || true
  kubectl delete pvc --namespace gitea-runner --all --ignore-not-found 2>/dev/null || true
  kubectl delete namespace gitea-runner --ignore-not-found
}

case "${1:-install}" in
  install) install ;;
  uninstall) uninstall ;;
  purge) purge ;;
  *) echo "Usage: $0 [install|uninstall|purge]"; exit 1 ;;
esac
