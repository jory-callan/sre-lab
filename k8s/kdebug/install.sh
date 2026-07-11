#!/bin/bash
# install.sh — kdebug 调试工具部署（从本地 Nexus）
# 用法: bash install.sh
# 前置条件: 本地 Nexus，chart 需先通过 download.sh 推送
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NS="kdebug"
CHART_VERSION="0.1.0"
NEXUS_HELM="http://192.168.5.103:8081/repository/helm-hosted/"

# ── 初始化 ──────────────────────────────────────────
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

# ── 从本地 Nexus 安装 ──────────────────────────────
helm repo add helm-hosted "$NEXUS_HELM" 2>/dev/null || true
helm repo update 2>/dev/null

helm upgrade --install kdebug helm-hosted/kdebug \
  --namespace "$NS" \
  --version "$CHART_VERSION" \
  --values "$SCRIPT_DIR/helm/values.yaml" \
  --wait --timeout 5m

# ── 输出 ──────────────────────────────────────────────
echo ""
echo "✅ kdebug 部署完成"
echo ""
echo "   内部: ${NS}.${NS}.svc.cluster.local:80"
echo "   Web:  https://kdebug.czw-sre.internal"
echo "   NodePort: <node-ip>:30302"
echo ""
echo "   检查: kubectl -n $NS get pods"
echo "   验证: curl -k https://kdebug.czw-sre.internal/ping"
echo "   日志: kubectl -n $NS logs deploy/kdebug --tail=50"
echo "   Chart: 本地 Nexus (${NEXUS_HELM})"
echo ""
