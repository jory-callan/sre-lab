#!/bin/bash
# download.sh — 打包 kdebug Helm chart 并推送到本地 Nexus
# 用法: bash download.sh [version]
# 默认 version: 0.1.0
set -euo pipefail

CHART_VERSION="${1:-0.1.0}"
CHART_NAME="kdebug"
NEXUS_HELM="http://192.168.5.103:8081/repository/helm-hosted/"
TMP_DIR="/tmp/${CHART_NAME}-chart"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── 打包 ──────────────────────────────────────────────
echo ">> 打包 ${CHART_NAME} chart ${CHART_VERSION} ..."
helm package "$SCRIPT_DIR/helm" \
  --destination "$TMP_DIR" \
  --version "$CHART_VERSION" \
  --app-version "$CHART_VERSION"

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
