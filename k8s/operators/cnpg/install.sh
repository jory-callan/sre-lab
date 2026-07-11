#!/bin/bash
# install.sh — CloudNativePG Operator
# 安装到 operators 命名空间
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="operators"
CHART_VERSION="0.28.2"
CHART_FILE="$SCRIPT_DIR/cloudnative-pg-${CHART_VERSION}.tgz"

# 确保命名空间 + 配额
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "$SCRIPT_DIR/../resourcequota.yaml"

# 下载 chart
if [ ! -f "$CHART_FILE" ]; then
  echo ">> 下载 CloudNativePG chart ${CHART_VERSION} ..."
  helm repo add cnpg https://cloudnative-pg.github.io/charts 2>/dev/null || true
  helm pull cnpg/cloudnative-pg --version "$CHART_VERSION" --destination "$SCRIPT_DIR/"
fi

# 安装 operator
if ! helm list -n "$NAMESPACE" 2>/dev/null | grep -q cnpg; then
  echo ">> 安装 CloudNativePG operator ..."
  helm upgrade --install cnpg "$CHART_FILE" \
    --namespace "$NAMESPACE" \
    --values "$SCRIPT_DIR/values.yaml" \
    --timeout 5m --wait
  kubectl rollout status deployment/cnpg-cloudnative-pg -n "$NAMESPACE" --timeout=120s
fi

echo ""
echo "✅ CloudNativePG operator 安装完成"
echo "   命名空间: $NAMESPACE"
echo "   版本: $CHART_VERSION"
echo ""
echo ">> 接下来安装 PostgreSQL 实例:"
echo "   cd ../postgres && bash install.sh standalone"
