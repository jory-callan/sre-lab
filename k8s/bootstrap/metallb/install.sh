#!/bin/bash
# install.sh -- 安装 MetalLB LoadBalancer
# 用法: bash install.sh
# 前置条件: Cilium 或其它 CNI 已就绪，kubectl 连接正常
set -euo pipefail

METALLB_VERSION="0.16.1"
MIRROR_BASE="${MIRROR_BASE:-https://gh-proxy.com}"
CHARTS_DIR="$(cd "$(dirname "$0")/../charts" && pwd)"
CHART_FILE="$CHARTS_DIR/metallb-${METALLB_VERSION}.tgz"

# 检查是否已安装
if helm list -n metallb-system 2>/dev/null | grep -q metallb; then
    echo "[INFO]  MetalLB 已安装，跳过"
    exit 0
fi

# 本地 chart 不存在时，从远程下载
if [ ! -f "$CHART_FILE" ]; then
    echo ">> 本地 chart 未找到，下载 MetalLB ${METALLB_VERSION} ..."
    local_url="${MIRROR_BASE:+"${MIRROR_BASE}/"}https://github.com/metallb/metallb/releases/download/metallb-chart-${METALLB_VERSION}/metallb-${METALLB_VERSION}.tgz"
    curl -fsSL "$local_url" -o "$CHART_FILE" --connect-timeout 30 --retry 3
fi

echo ">> 安装 MetalLB ..."
helm upgrade --install metallb "$CHART_FILE" \
    --namespace metallb-system --create-namespace \
    --wait --timeout 5m

echo "[OK] MetalLB 安装完成"
echo ""
echo "   下一步: 创建 IP 地址池"
echo "     kubectl apply -f metallb-ipaddresspool.yaml"
echo "     kubectl apply -f metallb-l2advertisement.yaml"
echo ""
echo "   示例配置见同级 README.md"
