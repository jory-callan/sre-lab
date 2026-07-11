#!/bin/bash
# install.sh — 安装 Gitea 1.26.4
# 用法: bash install.sh
# 前置条件: ingress-nginx + MetalLB + NFS StorageClass 已就绪
set -euo pipefail

NAMESPACE="gitea"
VALUES_FILE="$(cd "$(dirname "$0")" && pwd)/gitea-values.yaml"

# 检查是否已安装
if helm list -n "$NAMESPACE" 2>/dev/null | grep -q gitea; then
    echo "ℹ️  Gitea 已安装，跳过"
    exit 0
fi

# 添加 Gitea Helm repo
echo "▶ 添加 Gitea Helm repo ..."
helm repo add gitea-charts https://dl.gitea.com/charts/ 2>/dev/null || true
helm repo update 2>/dev/null

# 安装 Gitea
echo "▶ 安装 Gitea 1.26.4 (SQLite + NFS + ingress)..."
helm upgrade --install gitea gitea-charts/gitea \
    --namespace "$NAMESPACE" --create-namespace \
    --values "$VALUES_FILE" \
    --wait --timeout 10m

echo "✅ Gitea 安装完成"
echo ""
echo "   访问地址: https://gitea.czw-sre.internal"
echo "   (确保 *.czw-sre.internal → 192.168.5.205 DNS 已配置)"
echo ""
echo "   首次访问会进入安装页面，填写:"
echo "     数据库类型: SQLite"
echo "     站点名称: Gitea"
echo "     管理员账号: 自行设置"
echo ""
echo "   查看状态:"
echo "     kubectl -n gitea get pods"
echo "     kubectl -n gitea get svc"
echo "     kubectl -n gitea get ingress"
echo ""
echo "   查看日志:"
echo "     kubectl -n gitea logs deploy/gitea --tail=50"
