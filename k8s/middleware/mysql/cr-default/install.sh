#!/bin/bash
# install.sh — MySQL cluster 实例（Percona Operator）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME="mysql-default"
NAMESPACE="mysql"

install() {
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -f "$SCRIPT_DIR/cr-secret.yaml" --namespace "$NAMESPACE"
  kubectl apply -f "$SCRIPT_DIR/cr-mysql-cr.yaml" --namespace "$NAMESPACE"
  kubectl apply -f "$SCRIPT_DIR/cr-service-external.yaml" --namespace "$NAMESPACE"
  echo "完成"
}

uninstall() {
  kubectl delete -f "$SCRIPT_DIR/cr-mysql-cr.yaml" --namespace "$NAMESPACE" 2>/dev/null || true
  kubectl delete -f "$SCRIPT_DIR/cr-service-external.yaml" --namespace "$NAMESPACE" 2>/dev/null || true
  kubectl delete -f "$SCRIPT_DIR/cr-secret.yaml" --namespace "$NAMESPACE" 2>/dev/null || true
  echo "完成"
}

case "${1:-install}" in install) install ;; uninstall) uninstall ;; *) echo "Usage: $0 [install|uninstall]"; exit 1 ;; esac
