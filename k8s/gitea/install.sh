#!/bin/bash
# install.sh — Gitea 1.26.4 部署
# 用法: bash install.sh
# 前置条件: ingress-nginx + MetalLB + NFS StorageClass 已就绪
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NS="gitea"

# ── 初始化 ──────────────────────────────────────────
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "$SCRIPT_DIR/resourcequota.yaml"

# ── 添加 Helm repo ──────────────────────────────────
helm repo add gitea-charts https://dl.gitea.com/charts/ 2>/dev/null || true
helm repo update 2>/dev/null

# ── 部署 ─────────────────────────────────────────────
helm upgrade --install gitea gitea-charts/gitea \
  --namespace "$NS" \
  --values "$SCRIPT_DIR/values.yaml" \
  --wait --timeout 10m

# ── 输出 ──────────────────────────────────────────────
echo ""
echo "✅ Gitea 部署完成"
echo ""
echo "   地址: https://gitea.czw-sre.internal"
echo "   管理员: admin / admin123"
echo ""
echo "   检查: kubectl -n gitea get pods"
echo "   日志: kubectl -n gitea logs deploy/gitea --tail=50"
echo "   指标: https://gitea.czw-sre.internal/metrics"
echo ""
echo "   说明: *.czw-sre.internal → 192.168.5.205 DNS 需已配置"
echo ""
