#!/bin/bash
# install.sh — kube-prometheus-stack 监控栈
# 用法: bash install.sh [--logs]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="monitoring"
RELEASE="kube-prometheus-stack"
CHART_VERSION="85.1.3"
CHART_FILE="$SCRIPT_DIR/helm/kube-prometheus-stack-${CHART_VERSION}.tgz"
INSTALL_LOGS=false
[[ "${1:-}" == "--logs" ]] && INSTALL_LOGS=true

# 下载 chart
if [ ! -f "$CHART_FILE" ]; then
  echo ">> 下载 kube-prometheus-stack chart ${CHART_VERSION} ..."
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
  helm pull prometheus-community/kube-prometheus-stack --version "$CHART_VERSION" --destination "$SCRIPT_DIR/helm/"
  mv "$SCRIPT_DIR/helm/kube-prometheus-stack-${CHART_VERSION}.tgz" "$CHART_FILE" 2>/dev/null || true
fi

# 安装
echo ">> 安装 kube-prometheus-stack ..."
helm upgrade --install "$RELEASE" "$CHART_FILE" \
  --namespace "$NAMESPACE" --create-namespace \
  --values "$SCRIPT_DIR/helm/values-prod.yaml" \
  --timeout 10m --wait

echo ""
echo "✅ 监控栈部署完成"
echo "   Grafana: http://monitor.czw-sre.internal (admin / admin123)"
echo "   查看: kubectl -n $NAMESPACE get pods"

# 可选日志采集
if [ "$INSTALL_LOGS" = true ]; then
  echo ""
  echo ">> 部署日志采集 (VictoriaLogs + Fluent Bit) ..."
  kubectl apply -f "$SCRIPT_DIR/victoria-logs/"
  kubectl apply -f "$SCRIPT_DIR/fluent-bit/"
  kubectl apply -f "$SCRIPT_DIR/grafana/"
  echo "✅ 日志采集部署完成"
fi
