#!/bin/bash
# install.sh — PostgreSQL HA 实例
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME="pg-ha"
NAMESPACE="postgres"
install() {
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  bash "$SCRIPT_DIR/dep-minio-setup.sh" 2>/dev/null || true
  kubectl apply -f "$SCRIPT_DIR/cr-secret.yaml" --namespace "$NAMESPACE"
  kubectl apply -f "$SCRIPT_DIR/cr-cluster.yaml" --namespace "$NAMESPACE"
  kubectl apply -f "$SCRIPT_DIR/cr-pooler.yaml" --namespace "$NAMESPACE"
  kubectl apply -f "$SCRIPT_DIR/cr-scheduled-backup.yaml" --namespace "$NAMESPACE"
  kubectl apply -f "$SCRIPT_DIR/cr-service-external.yaml" --namespace "$NAMESPACE"
  kubectl apply -f "$SCRIPT_DIR/cr-pod-monitor.yaml" --namespace "$NAMESPACE"
  echo "done"
}
uninstall() {
  kubectl delete -f "$SCRIPT_DIR/cr-pooler.yaml" --namespace "$NAMESPACE" 2>/dev/null || true
  kubectl delete -f "$SCRIPT_DIR/cr-scheduled-backup.yaml" --namespace "$NAMESPACE" 2>/dev/null || true
  kubectl delete -f "$SCRIPT_DIR/cr-cluster.yaml" --namespace "$NAMESPACE" 2>/dev/null || true
  kubectl delete -f "$SCRIPT_DIR/cr-secret.yaml" --namespace "$NAMESPACE" 2>/dev/null || true
  kubectl delete -f "$SCRIPT_DIR/cr-service-external.yaml" --namespace "$NAMESPACE" 2>/dev/null || true
  kubectl delete -f "$SCRIPT_DIR/cr-pod-monitor.yaml" --namespace "$NAMESPACE" 2>/dev/null || true
  echo "done"
}
case "${1:-install}" in install) install ;; uninstall) uninstall ;; *) echo "Usage: $0 [install|uninstall]"; exit 1 ;; esac
