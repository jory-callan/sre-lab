#!/bin/bash
# install.sh — Redis Sentinel HA 实例（1 主 2 从 + 3 Sentinel）
# Usage: bash install.sh [install|uninstall|purge]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== 配置区 =====
NAME="redis-core"
NAMESPACE="redis"
CHART="$SCRIPT_DIR/../chart"
VALUES="$SCRIPT_DIR/values.yaml"
# ==================

install() {
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  # 标记 Helm ownership
  kubectl label namespace "$NAMESPACE" app.kubernetes.io/managed-by=Helm --overwrite 2>/dev/null || true
  kubectl annotate namespace "$NAMESPACE" meta.helm.sh/release-name="$NAME" --overwrite 2>/dev/null || true
  kubectl annotate namespace "$NAMESPACE" meta.helm.sh/release-namespace="$NAMESPACE" --overwrite 2>/dev/null || true

  # 前置依赖：共享 Secret（幂等）
  kubectl apply -f "$SCRIPT_DIR/cr-secret.yaml" --namespace "$NAMESPACE"

  # Helm 部署 RedisFailover / Service / Backup
  helm upgrade --install "$NAME" "$CHART" \
    --namespace "$NAMESPACE" \
    --values "$VALUES" \
    --timeout 5m --wait
}

uninstall() {
  # 卸载服务，保留 PVC / PV / 数据
  helm uninstall "$NAME" --namespace "$NAMESPACE"
}

purge() {
  # 完全卸载
  helm uninstall "$NAME" --namespace "$NAMESPACE" 2>/dev/null || true
  kubectl delete namespace "$NAMESPACE" --ignore-not-found
}

case "${1:-install}" in
  install) install ;;
  uninstall) uninstall ;;
  purge) purge ;;
  *) echo "Usage: $0 [install|uninstall|purge]"; exit 1 ;;
esac
