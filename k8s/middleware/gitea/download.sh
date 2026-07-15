#!/bin/bash
# download.sh — 下载 Gitea Helm chart 并推送到本地 Nexus
# 用法: bash download.sh [chart-version]
# 默认 chart-version: 12.6.0（Gitea 1.26.x）
set -euo pipefail

CHART_VERSION="${1:-12.6.0}"
CHART_NAME="gitea"
NEXUS_HELM="http://192.168.5.103:8081/repository/helm-hosted/"
TMP_DIR="/tmp/${CHART_NAME}-chart"

# ── 下载 ──────────────────────────────────────────────
mkdir -p "$TMP_DIR"
helm repo add "${CHART_NAME}-charts" "https://dl.gitea.com/charts/" 2>/dev/null || true
helm repo update 2>/dev/null

echo ">> 下载 ${CHART_NAME} chart ${CHART_VERSION} ..."
helm pull "${CHART_NAME}-charts/${CHART_NAME}" \
  --version "$CHART_VERSION" \
  --destination "$TMP_DIR"

# ── 推送到本地 Nexus ────────────────────────────────
echo ">> 推送到本地 Nexus ..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  --upload-file "$TMP_DIR/${CHART_NAME}-${CHART_VERSION}.tgz" \
  "$NEXUS_HELM")

case "$HTTP_CODE" in
  200) echo "   ✅ ${CHART_NAME} ${CHART_VERSION} 已推送成功" ;;
  400) echo "   ℹ️  Nexus 已存在此版本，跳过推送" ;;
  *)   echo "   ⚠️  返回码 $HTTP_CODE，请检查 Nexus 状态" ;;
esac

echo ""
echo "   仓库: ${NEXUS_HELM}"
echo "   Chart: ${CHART_NAME}-${CHART_VERSION}.tgz"
echo "   安装: cd $(dirname "$0") && bash install.sh"
