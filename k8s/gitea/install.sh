#!/bin/bash
# install.sh — Gitea 1.26.4 部署（从本地 Nexus）
# 用法: bash install.sh
# 前置条件: ingress-nginx + MetalLB + NFS StorageClass + 本地 Nexus
#           chart 需先通过 download.sh 推送到 Nexus
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NS="gitea"
CHART_VERSION="12.6.0"
NEXUS_HELM="http://192.168.5.103:8081/repository/helm-hosted/"

# ── 初始化 ──────────────────────────────────────────
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "$SCRIPT_DIR/resourcequota.yaml"

# ── 从本地 Nexus 安装 ──────────────────────────────
helm repo add helm-hosted "$NEXUS_HELM" 2>/dev/null || true
helm repo update 2>/dev/null

helm upgrade --install gitea helm-hosted/gitea \
  --namespace "$NS" \
  --version "$CHART_VERSION" \
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
echo "   Chart 来源: 本地 Nexus (${NEXUS_HELM})"
echo ""
