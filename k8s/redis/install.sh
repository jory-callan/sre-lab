#!/bin/bash
# install.sh — Redis (OT-Container-KIT Operator)
# 用法: bash install.sh [standalone|sentinel-ha|cluster]
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-standalone}"
OPERATOR_NS="redis-operator"
REDIS_NS="redis"
CHART_VERSION="0.25.0"
CHART_FILE="$SCRIPT_DIR/helm/redis-operator-${CHART_VERSION}.tgz"

# 下载 chart
if [ ! -f "$CHART_FILE" ]; then
  echo ">> 下载 redis-operator chart ${CHART_VERSION} ..."
  helm repo add ot-helm https://ot-container.github.io/helm-charts/ 2>/dev/null || true
  helm pull ot-helm/redis-operator --version "$CHART_VERSION" --destination "$SCRIPT_DIR/helm/"
  mv "$SCRIPT_DIR/helm/redis-operator-${CHART_VERSION}.tgz" "$CHART_FILE" 2>/dev/null || true
fi

# 安装 operator
if ! helm list -n "$OPERATOR_NS" 2>/dev/null | grep -q redis-operator; then
  echo ">> 安装 redis-operator ..."
  helm upgrade --install redis-operator "$CHART_FILE" \
    --namespace "$OPERATOR_NS" --create-namespace \
    --values "$SCRIPT_DIR/helm/values-prod.yaml" \
    --timeout 5m --wait
fi

# 创建 namespace + 应用 CR
kubectl create namespace "$REDIS_NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "$SCRIPT_DIR/operator/$MODE/"

echo ""
echo "✅ Redis $MODE 部署完成"
echo "   查看: kubectl get redis,redisreplication,rediscluster -n $REDIS_NS"
