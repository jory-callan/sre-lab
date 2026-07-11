#!/bin/bash
# install.sh — victoria-metrics-k8s-stack (VMSingle + VMAgent + VMAlert + Grafana + NodeExporter + VictoriaLogs)
# 用法: bash install.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="vm-stack"

# 创建命名空间
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# ── 1. VictoriaMetrics k8s-stack ──────────────────────
echo ">> 安装 victoria-metrics-k8s-stack ..."
helm upgrade --install victoriametrics "$SCRIPT_DIR/victoria-metrics-k8s-stack-0.85.2.tgz" \
  --namespace "$NAMESPACE" \
  --values "$SCRIPT_DIR/values-vm-stack.yaml" \
  --timeout 10m --wait

# ── 2. VictoriaLogs ───────────────────────────────────
echo ">> 安装 VictoriaLogs ..."
helm upgrade --install victorialogs "$SCRIPT_DIR/victoria-logs-single-0.13.8.tgz" \
  --namespace "$NAMESPACE" \
  --values "$SCRIPT_DIR/values-vlogs.yaml" \
  --timeout 5m --wait

# ── 3. VictoriaLogs Collector ─────────────────────────
echo ">> 安装 VictoriaLogs Collector ..."
helm upgrade --install vmlogs-collector "$SCRIPT_DIR/victoria-logs-collector-0.3.6.tgz" \
  --namespace "$NAMESPACE" \
  --values "$SCRIPT_DIR/values-vlogscollector.yaml" \
  --timeout 5m --wait

echo ""
echo "✅ victoria-metrics-k8s-stack 部署完成"
echo "   Grafana-VM: https://vm-grafana.czw-sre.internal (admin/admin)"
echo "   VMSingle:   https://vm-metrics.czw-sre.internal"
echo "   VictoriaLogs: https://vm-logs.czw-sre.internal"
echo "   查看: kubectl -n $NAMESPACE get pods"
