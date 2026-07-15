#!/bin/bash
# install.sh — Velero 集群备份 (MinIO S3 后端)
# 用法: bash install.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="velero"
CHART_VERSION="8.5.1"
CHART_FILE="$SCRIPT_DIR/velero-${CHART_VERSION}.tgz"

# 下载 chart
if [ ! -f "$CHART_FILE" ]; then
  echo ">> 下载 Velero chart ${CHART_VERSION} ..."
  helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts 2>/dev/null || true
  helm pull vmware-tanzu/velero --version "$CHART_VERSION" --destination "$SCRIPT_DIR/"
  mv "$SCRIPT_DIR/velero-${CHART_VERSION}.tgz" "$CHART_FILE" 2>/dev/null || true
fi

# 创建 namespace + Secret
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "$SCRIPT_DIR/secret.yaml"

# 安装
echo ">> 安装 Velero ..."
helm upgrade --install velero "$CHART_FILE" \
  --namespace "$NAMESPACE" \
  --values "$SCRIPT_DIR/values.yaml" \
  --timeout 5m --wait

echo ""
echo "✅ Velero 部署完成"
echo "   备份目标: MinIO (bucket: velero)"
echo "   定时备份: 每天 02:00"
echo "   查看: kubectl -n $NAMESPACE get pods"
echo "   手动备份: velero backup create manual-\$(date +%Y%m%d)"
