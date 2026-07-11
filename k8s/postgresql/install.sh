#!/bin/bash
# install.sh — PostgreSQL 17 (CloudNativePG Operator)
# 用法: bash install.sh [standalone|ha]
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-standalone}"
OPERATOR_NS="cnpg-system"
PG_NS="postgresql"
CHART_VERSION="0.28.2"
CHART_FILE="$SCRIPT_DIR/helm/cloudnative-pg-${CHART_VERSION}.tgz"

# 下载 chart
if [ ! -f "$CHART_FILE" ]; then
  echo ">> 下载 CloudNativePG chart ${CHART_VERSION} ..."
  helm repo add cnpg https://cloudnative-pg.github.io/charts 2>/dev/null || true
  helm pull cnpg/cloudnative-pg --version "$CHART_VERSION" --destination "$SCRIPT_DIR/helm/"
  mv "$SCRIPT_DIR/helm/cloudnative-pg-${CHART_VERSION}.tgz" "$CHART_FILE" 2>/dev/null || true
fi

# 安装 operator
if ! helm list -n "$OPERATOR_NS" 2>/dev/null | grep -q cnpg; then
  echo ">> 安装 CloudNativePG operator ..."
  helm upgrade --install cnpg "$CHART_FILE" \
    --namespace "$OPERATOR_NS" --create-namespace \
    --values "$SCRIPT_DIR/helm/values-prod.yaml" \
    --timeout 5m --wait
  kubectl rollout status deployment/cnpg-controller-manager -n "$OPERATOR_NS" --timeout=120s
fi

# 创建 namespace + 公共 Secret
kubectl create namespace "$PG_NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "$SCRIPT_DIR/operator/common/"

# 应用模式 CR
kubectl apply -f "$SCRIPT_DIR/operator/$MODE/"

echo ""
echo "✅ PostgreSQL $MODE 部署完成"
echo "   连接: psql -h pg-${MODE}-rw.${PG_NS}.svc.cluster.local -U postgres -d appdb"
echo "   密码: pg@czw"
echo "   查看: kubectl get cluster -n $PG_NS"
