#!/bin/bash
# install.sh — MinIO 对象存储 (MinIO Operator)
# 用法: bash install.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPERATOR_NS="minio-operator"
TENANT_NS="minio"
CHART_VERSION="7.1.1"
CHART_FILE="$SCRIPT_DIR/minio-operator-${CHART_VERSION}.tgz"

# 下载 operator chart
if [ ! -f "$CHART_FILE" ]; then
  echo ">> 下载 MinIO Operator chart ${CHART_VERSION} ..."
  helm repo add minio-operator https://operator.min.io/ 2>/dev/null || true
  helm pull minio-operator/operator --version "$CHART_VERSION" --destination "$SCRIPT_DIR/"
  mv "$SCRIPT_DIR/operator-${CHART_VERSION}.tgz" "$CHART_FILE" 2>/dev/null || true
fi

# 安装 operator
if ! helm list -n "$OPERATOR_NS" 2>/dev/null | grep -q minio-operator; then
  echo ">> 安装 MinIO Operator ..."
  helm upgrade --install minio-operator "$CHART_FILE" \
    --namespace "$OPERATOR_NS" --create-namespace \
    --timeout 5m --wait
fi

# 创建 tenant namespace + 应用资源
kubectl create namespace "$TENANT_NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "$SCRIPT_DIR/"

echo ""
echo "✅ MinIO 部署完成"
echo "   API: http://minio.czw-sre.internal"
echo "   Console: http://minio-console.czw-sre.internal"
echo "   账号: minioadmin / minioadmin"
echo "   查看: kubectl -n $TENANT_NS get pods"
