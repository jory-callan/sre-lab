#!/bin/bash
# install.sh — 安装 Kite K8s Web UI v0.12.3
# 用法: bash install.sh
# 前置条件: ingress-nginx + NFS StorageClass 已就绪
set -euo pipefail

NAMESPACE="kite"
VALUES_FILE="$(cd "$(dirname "$0")" && pwd)/kite-values.yaml"

# 检查是否已安装
if helm list -n "$NAMESPACE" 2>/dev/null | grep -q kite; then
    echo "ℹ️  Kite 已安装，跳过"
    exit 0
fi

# 安装 Kite
echo "▶ 安装 Kite v0.12.3 (SQLite + NFS + ingress)..."
helm upgrade --install kite oci://ghcr.io/kite-org/charts/kite \
    --namespace "$NAMESPACE" --create-namespace \
    --values "$VALUES_FILE" \
    --version 0.12.3 \
    --wait --timeout 5m

# 创建 NodePort Service（与 Helm 管理的 ClusterIP Service 并存）
kubectl apply -f "$(dirname "$0")/service.yaml"

echo ""
echo "✅ Kite 安装完成"
echo ""
echo "   访问地址: http://kite.czw-sre.internal"
echo "   (确保 *.czw-sre.internal → 192.168.5.205 DNS 已配置)"
echo ""
echo "   或通过 NodePort: http://<任意节点IP>:30301"
echo ""
echo "   首次访问会进入设置页面，创建管理员账号即可使用。"
echo ""
echo "   查看状态:"
echo "     kubectl -n kite get pods"
echo "     kubectl -n kite get ingress"
echo ""
echo "   查看日志:"
echo "     kubectl -n kite logs deploy/kite --tail=50"
