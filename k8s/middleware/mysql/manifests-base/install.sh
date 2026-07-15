#!/bin/bash
# install.sh — MySQL standalone（raw manifests）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="mysql"

install() {
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -f "$SCRIPT_DIR/secret.yaml" --namespace "$NAMESPACE"
  kubectl apply -f "$SCRIPT_DIR/configmap.yaml" --namespace "$NAMESPACE"
  kubectl apply -f "$SCRIPT_DIR/pvc.yaml" --namespace "$NAMESPACE"
  kubectl apply -f "$SCRIPT_DIR/service.yaml" --namespace "$NAMESPACE"
  kubectl apply -f "$SCRIPT_DIR/statefulset.yaml" --namespace "$NAMESPACE"
  echo "完成"
}

uninstall() {
  kubectl delete -f "$SCRIPT_DIR/statefulset.yaml" --namespace "$NAMESPACE" 2>/dev/null || true
  kubectl delete -f "$SCRIPT_DIR/service.yaml" --namespace "$NAMESPACE" 2>/dev/null || true
  kubectl delete -f "$SCRIPT_DIR/pvc.yaml" --namespace "$NAMESPACE" 2>/dev/null || true
  kubectl delete -f "$SCRIPT_DIR/configmap.yaml" --namespace "$NAMESPACE" 2>/dev/null || true
  kubectl delete -f "$SCRIPT_DIR/secret.yaml" --namespace "$NAMESPACE" 2>/dev/null || true
  echo "完成"
}

case "${1:-install}" in install) install ;; uninstall) uninstall ;; *) echo "Usage: $0 [install|uninstall]"; exit 1 ;; esac
