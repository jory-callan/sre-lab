#!/bin/bash
# kube-prometheus-stack 卸载脚本
# 支持选择性卸载指标/日志组件
#
# 用法：
#   ./uninstall.sh            # 卸载全部（指标 + 日志 + PVC + 命名空间）
#   ./uninstall.sh --metrics  # 仅卸载指标（kube-prometheus-stack）
#   ./uninstall.sh --logs     # 仅卸载日志（VictoriaLogs + Fluent Bit）

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="monitoring"
RELEASE="kube-prometheus-stack"
REMOVE_METRICS=false
REMOVE_LOGS=false

# 默认全部卸载
if [ $# -eq 0 ]; then
  REMOVE_METRICS=true
  REMOVE_LOGS=true
else
  for arg in "$@"; do
    case "$arg" in
      --metrics) REMOVE_METRICS=true ;;
      --logs) REMOVE_LOGS=true ;;
    esac
  done
fi

# ============================================
# 卸载日志组件
# ============================================
if [ "$REMOVE_LOGS" = true ]; then
  echo "🗑️  卸载日志采集组件..."

  echo "   ├─ Grafana VictoriaLogs 数据源..."
  kubectl delete -f "$SCRIPT_DIR/grafana/" --ignore-not-found=true

  echo "   ├─ Fluent Bit..."
  kubectl delete -f "$SCRIPT_DIR/fluent-bit/" --ignore-not-found=true

  echo "   └─ VictoriaLogs（含 PVC）..."
  kubectl delete -f "$SCRIPT_DIR/victoria-logs/" --ignore-not-found=true
fi

# ============================================
# 卸载指标组件
# ============================================
if [ "$REMOVE_METRICS" = true ]; then
  echo ""
  echo "🗑️  卸载 kube-prometheus-stack..."

  # 卸载 Helm Release
  helm uninstall "$RELEASE" --namespace "$NAMESPACE" 2>/dev/null || true

  # 删除命名空间
  kubectl delete namespace "$NAMESPACE" --ignore-not-found=true

  # 清理 CRDs
  echo ""
  echo "⚠️  如需清理 CRD，请手动执行："
  echo "   kubectl delete crd -l app.kubernetes.io/instance=kube-prometheus-stack"

  # PVC 随命名空间删除。如果只卸载指标但保留日志，提示用户注意
  if [ "$REMOVE_LOGS" = false ]; then
    echo ""
    echo "⚠️  命名空间已删除！日志组件的 PVC 也随命名空间一起删除了。"
    echo "   如需保留日志数据，请在删除命名空间前先备份。"
  fi
fi

echo ""
echo "✅ 卸载完成"