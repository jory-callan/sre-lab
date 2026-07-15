#!/bin/bash
# install.sh — PostgreSQL standalone 实例
# Usage: bash install.sh [install|uninstall]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== 配置区 =====
NAME="pg-standalone"
NAMESPACE="postgres"
# ==================

install() {
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  echo ">> 配置 MinIO 依赖..."
  bash "$SCRIPT_DIR/dep-minio-setup.sh" 2>/dev/null || true
  echo ">> 创建 Secret..."
  kubectl apply -f "$SCRIPT_DIR/cr-secret.yaml" --namespace "$NAMESPACE"
  echo ">> 创建 PostgreSQL 实例..."
  kubectl apply -f "$SCRIPT_DIR/cr-cluster.yaml" --namespace "$NAMESPACE"
  echo ">> 创建 Service..."
  kubectl apply -f "$SCRIPT_DIR/cr-service-external.yaml" --namespace "$NAMESPACE"
  echo ">> 配置监控..."
  kubectl apply -f "$SCRIPT_DIR/cr-pod-monitor.yaml" --namespace "$NAMESPACE"
  kubectl apply -f "$SCRIPT_DIR/../common/cnpg-alerts.yaml" --namespace "$NAMESPACE" 2>/dev/null || true
  echo "✅ 实例部署完成"
}

uninstall() {
  kubectl delete -f "$SCRIPT_DIR/cr-cluster.yaml" --namespace "$NAMESPACE" 2>/dev/null || true
  kubectl delete -f "$SCRIPT_DIR/cr-secret.yaml" --namespace "$NAMESPACE" 2>/dev/null || true
  kubectl delete -f "$SCRIPT_DIR/cr-service-external.yaml" --namespace "$NAMESPACE" 2>/dev/null || true
  kubectl delete -f "$SCRIPT_DIR/cr-pod-monitor.yaml" --namespace "$NAMESPACE" 2>/dev/null || true
  kubectl delete -f "$SCRIPT_DIR/../common/cnpg-alerts.yaml" --namespace "$NAMESPACE" 2>/dev/null || true
  echo "✅ 实例已卸载（PVC 保留，手动清理: kubectl delete pvc -n $NAMESPACE --all）"
}

case "${1:-install}" in
  install) install ;;
  uninstall) uninstall ;;
  *) echo "Usage: $0 [install|uninstall]"; exit 1 ;;
esac
