#!/bin/bash
# install.sh — Kite K8s Web UI v0.13.0
# 用法: bash install.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="kite"
CHART_DIR="$SCRIPT_DIR/helm"

if ! helm list -n "$NAMESPACE" 2>/dev/null | grep -q kite; then
  echo ">> 安装 Kite v0.13.0 ..."
  helm upgrade --install kite "$CHART_DIR" \
    --namespace "$NAMESPACE" --create-namespace \
    --values "$SCRIPT_DIR/values.yaml" \
    --wait --timeout 5m
fi

echo ""
echo "✅ Kite 安装完成"
echo "   访问: https://kite.czw-sre.internal"
echo "   查看: kubectl -n $NAMESPACE get pods"
