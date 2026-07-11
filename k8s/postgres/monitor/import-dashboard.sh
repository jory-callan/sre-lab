#!/bin/bash
# import-dashboard.sh — 自动导入 CNPG Grafana Dashboard
#
# 用法:
#   bash import-dashboard.sh                          # 默认（vm-grafana.czw-sre.internal）
#   GRAFANA_URL=https://grafana.example.com bash import-dashboard.sh
#   GRAFANA_PASS=admin456 bash import-dashboard.sh
#
# 原理: 通过 Grafana API 导入 Dashboard JSON，自动映射 Prometheus 数据源
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASHBOARD_FILE="$SCRIPT_DIR/dashboard/cnpg-cluster.json"
GRAFANA_URL="${GRAFANA_URL:-https://vm-grafana.czw-sre.internal}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASS="${GRAFANA_PASS:-admin123}"

if [ ! -f "$DASHBOARD_FILE" ]; then
  echo "❌ Dashboard 文件不存在: $DASHBOARD_FILE"
  exit 1
fi

# ── 验证 Grafana 可达 ────────────────────────────────────
echo ">> 检查 Grafana 连接 ..."
HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" \
  -u "$GRAFANA_USER:$GRAFANA_PASS" \
  "$GRAFANA_URL/api/org" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" != "200" ]; then
  echo "⚠️  无法连接 Grafana ($HTTP_CODE)"
  echo "   请设置 GRAFANA_URL / GRAFANA_USER / GRAFANA_PASS"
  echo "   例如: GRAFANA_URL=https://vm-grafana.czw-sre.internal GRAFANA_PASS=admin123 bash $0"
  exit 1
fi
echo "   ✅ 连接成功"

# ── 导入 Dashboard ───────────────────────────────────────
echo ">> 导入 Dashboard (cnpg-cluster.json) ..."

# 构建 API 请求：dashboard JSON + inputs 映射
# 使用 jq 拼接 payload，避免修改原 JSON
DASHBOARD_CONTENT=$(cat "$DASHBOARD_FILE")

PAYLOAD=$(jq -n \
  --argjson dashboard "$DASHBOARD_CONTENT" \
  '{
    dashboard: $dashboard,
    overwrite: true,
    inputs: [
      {
        name: "DS_PROMETHEUS",
        type: "datasource",
        pluginId: "prometheus",
        value: "VictoriaMetrics"
      }
    ]
  }')

RESPONSE=$(curl -sk -X POST \
  -u "$GRAFANA_USER:$GRAFANA_PASS" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  "$GRAFANA_URL/api/dashboards/db" 2>/dev/null)

# ── 检查结果 ──────────────────────────────────────────────
IMPORT_STATUS=$(echo "$RESPONSE" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('status', 'error'))
    if 'title' in d:
        print(f\"title={d['title']}\")
    if 'url' in d:
        print(f\"url={d['url']}\")
    if 'message' in d:
        print(f\"message={d['message']}\")
except:
    print('parse_error')
" 2>/dev/null)

if echo "$IMPORT_STATUS" | grep -q "success"; then
  TITLE=$(echo "$IMPORT_STATUS" | grep "^title=" | cut -d= -f2-)
  URL=$(echo "$IMPORT_STATUS" | grep "^url=" | cut -d= -f2-)
  echo "   ✅ 导入成功: $TITLE"
  echo "   🔗 $GRAFANA_URL$URL"
else
  MESSAGE=$(echo "$IMPORT_STATUS" | grep "^message=" | cut -d= -f2-)
  if [ -n "$MESSAGE" ]; then
    echo "   ⚠️  $MESSAGE"
  else
    echo "   ❌ 导入失败"
    echo "   $RESPONSE"
  fi
fi
