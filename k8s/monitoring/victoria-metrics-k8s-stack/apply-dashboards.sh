#!/bin/bash
# apply-dashboards.sh — 从本地 JSON 创建 Grafana Dashboard ConfigMaps
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="vm-stack"

for f in "$SCRIPT_DIR/dashboards"/*.json; do
  base=$(basename "$f" .json)
  name="vm-dashboard-${base}"
  echo ">> 创建 $name ..."
  # 大文件先创建再打 label（避免 annotation 大小限制）
  kubectl create configmap "$name" \
    --namespace "$NAMESPACE" \
    --from-file="$f" \
    --dry-run=client -o yaml 2>/dev/null | \
    python3 -c "
import sys,yaml,json
d=yaml.safe_load(sys.stdin)
d['metadata']['labels'] = d.get('metadata',{}).get('labels',{})
d['metadata']['labels']['grafana_dashboard'] = '1'
print(json.dumps(d))
" | kubectl apply -f- 2>/dev/null || {
    # 如果 inline label 失败，分两步
    kubectl create configmap "$name" \
      --namespace "$NAMESPACE" \
      --from-file="$f" -o yaml --dry-run=client 2>/dev/null | kubectl apply -f- 2>/dev/null
    kubectl label configmap -n "$NAMESPACE" "$name" grafana_dashboard="1" 2>/dev/null
  }
done
echo "✅ Grafana dashboards created"
