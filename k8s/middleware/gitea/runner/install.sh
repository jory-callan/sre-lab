#!/bin/bash
# install.sh — Gitea Actions Runner
# Usage: bash install.sh [install|uninstall|purge]
#   install    部署 runner（幂等）
#   uninstall  卸载 runner，保留 PVC / 数据
#   purge      完全卸载干净
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install() {
  kubectl apply -f "$SCRIPT_DIR/ci-deployer.yaml"
  kubectl apply -f "$SCRIPT_DIR/runner.yaml"
  kubectl -n gitea-runner rollout status deploy/gitea-runner --timeout=120s

  echo ""
  echo "✅ Runner 部署完成"
  echo ""
  echo "   ci-deployer token（存到 Gitea Secret KUBE_TOKEN）:"
  echo "   kubectl -n kube-system get secret ci-deployer-token -o jsonpath='{.data.token}' | base64 -d"
}

uninstall() {
  # 卸载 runner，保留 PVC（runner 注册信息）
  kubectl delete -f "$SCRIPT_DIR/runner.yaml" --ignore-not-found
  kubectl delete -f "$SCRIPT_DIR/ci-deployer.yaml" --ignore-not-found
  echo "✅ Runner 已卸载（PVC 保留）"
}

purge() {
  kubectl delete -f "$SCRIPT_DIR/runner.yaml" --ignore-not-found
  kubectl delete -f "$SCRIPT_DIR/ci-deployer.yaml" --ignore-not-found
  kubectl delete namespace gitea-runner --ignore-not-found
  echo "✅ Runner 已完全清理"
}

case "${1:-install}" in
  install) install ;;
  uninstall) uninstall ;;
  purge) purge ;;
  *) echo "Usage: $0 [install|uninstall|purge]"; exit 1 ;;
esac
