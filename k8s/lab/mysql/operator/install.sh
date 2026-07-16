#!/bin/bash
# install.sh — Percona MySQL Operator
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME="ps-operator"
NAMESPACE="operators"
CHART=""  # 需要先下载 chart: helm pull percona/ps-operator --version 1.1.0
VALUES="$SCRIPT_DIR/values.yaml"

install() {
  if [ -z "$CHART" ]; then
    echo "请先下载 Percona Operator chart:"
    echo "  helm repo add percona https://percona.github.io/percona-helm-charts/"
    echo "  helm pull percona/ps-operator --version 1.1.0 --untar"
    echo "  mv ps-operator percona-mysql-operator-1.1.0"
    exit 1
  fi
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  helm upgrade --install "$NAME" "$CHART" \
    --namespace "$NAMESPACE" \
    --values "$VALUES" \
    --timeout 5m --wait
}

uninstall() {
  helm uninstall "$NAME" --namespace "$NAMESPACE" 2>/dev/null || true
}

case "${1:-install}" in install) install ;; uninstall) uninstall ;; *) echo "Usage: $0 [install|uninstall]"; exit 1 ;; esac
