#!/bin/bash
# install.sh — Redis sentinel-ha 实例
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME="redis-sentinel-ha"
NAMESPACE="redis"

install() {
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -f "$SCRIPT_DIR/cr-secret.yaml" --namespace "$NAMESPACE"
  kubectl apply -f "$SCRIPT_DIR/cr-redis-failover.yaml" --namespace "$NAMESPACE"
  kubectl apply -f "$SCRIPT_DIR/cr-service-external.yaml" --namespace "$NAMESPACE"
  kubectl apply -f "$SCRIPT_DIR/cr-backup-cronjob.yaml" --namespace "$NAMESPACE"
  echo "✅ 实例部署完成"
}

uninstall() {
  kubectl delete -f "$SCRIPT_DIR/cr-backup-cronjob.yaml" --namespace "$NAMESPACE" 2>/dev/null || true
  kubectl delete -f "$SCRIPT_DIR/cr-service-external.yaml" --namespace "$NAMESPACE" 2>/dev/null || true
  kubectl delete -f "$SCRIPT_DIR/cr-redis-failover.yaml" --namespace "$NAMESPACE" 2>/dev/null || true
  kubectl delete -f "$SCRIPT_DIR/cr-secret.yaml" --namespace "$NAMESPACE" 2>/dev/null || true
  echo "✅ 实例已卸载"
}

case "${1:-install}" in install) install ;; uninstall) uninstall ;; *) echo "Usage: $0 [install|uninstall]"; exit 1 ;; esac
