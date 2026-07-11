#!/bin/bash
# install.sh -- 安装 cert-manager
# 用法: bash install.sh
# 前置条件: kubectl 连接正常
set -euo pipefail

CERT_VERSION="v1.19.6"
CHARTS_DIR="$(cd "$(dirname "$0")/../charts" && pwd)"
CHART_FILE="$CHARTS_DIR/cert-manager-${CERT_VERSION}.tgz"

# 检查是否已安装
if helm list -n cert-manager 2>/dev/null | grep -q cert-manager; then
    echo "[INFO] cert-manager 已安装，跳过"
    exit 0
fi

# 本地 chart 不存在时，从远程下载
if [ ! -f "$CHART_FILE" ]; then
    echo ">> 本地 chart 未找到，下载 cert-manager ${CERT_VERSION} ..."
    local_url="https://charts.jetstack.io/charts/cert-manager-${CERT_VERSION}.tgz"
    curl -fsSL "$local_url" -o "$CHART_FILE" --connect-timeout 30 --retry 3
fi

echo ">> 安装 cert-manager ${CERT_VERSION} ..."
helm upgrade --install cert-manager "$CHART_FILE" \
    --namespace cert-manager --create-namespace \
    --set crds.enabled=true \
    --set webhook.timeoutSeconds=30 \
    --wait --timeout 5m

echo "[OK] cert-manager 安装完成"
echo ""
echo "   验证:"
echo "     kubectl -n cert-manager get pods"
echo "     kubectl get crd | grep cert-manager"
echo ""
echo "   创建 ClusterIssuer 实例来配置证书签发:"
echo "     kubectl apply -f cert-manager/cluster-issuer.yaml"
