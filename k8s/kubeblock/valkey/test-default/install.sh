#!/bin/bash
# install.sh — Valkey 测试实例（KubeBlocks replication-8, 8.1.8）
# Usage: bash install.sh [install|uninstall|purge]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== 配置区 =====
NAME="valkey"
NAMESPACE="valkey"
CR_FILE="$SCRIPT_DIR/cluster.yaml"
SECRET_FILE="$SCRIPT_DIR/secret-account.yaml"
# ===================

install() {
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -f "$SECRET_FILE" --namespace "$NAMESPACE" 2>/dev/null || true
  kubectl apply -f "$CR_FILE" --namespace "$NAMESPACE"
  echo "Valkey 实例部署完成"
}

uninstall() {
  kubectl delete -f "$CR_FILE" --namespace "$NAMESPACE" 2>/dev/null || true
  echo "Valkey 实例已卸载"
}

purge() {
  kubectl delete -f "$CR_FILE" --namespace "$NAMESPACE" 2>/dev/null || true
  kubectl delete pvc --namespace "$NAMESPACE" --all --ignore-not-found 2>/dev/null || true
  kubectl delete namespace "$NAMESPACE" --ignore-not-found
  echo "Valkey 实例已完全清理"
}

case "${1:-install}" in
  install) install ;;
  uninstall) uninstall ;;
  purge) purge ;;
  *) echo "Usage: $0 [install|uninstall|purge]"; exit 1 ;;
esac
