#!/bin/bash
# install.sh — KubeBlocks apecloud-mysql 实例
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="mysql"
install() {
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -f "$SCRIPT_DIR/cr-cluster.yaml" --namespace "$NAMESPACE"
  echo "实例部署完成"
}
uninstall() {
  kubectl delete -f "$SCRIPT_DIR/cr-cluster.yaml" --namespace "$NAMESPACE" 2>/dev/null || true
  echo "实例已卸载"
}
case "${1:-install}" in install) install ;; uninstall) uninstall ;; *) echo "Usage: $0 [install|uninstall]"; exit 1 ;; esac
