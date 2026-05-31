#!/bin/bash
# kube-prometheus-stack 安装脚本 - 通过 Helm 部署完整监控栈
# 包含：Prometheus Operator + Prometheus + Grafana + AlertManager
#       + Node Exporter + kube-state-metrics + 默认仪表板
# 可选：VictoriaLogs + Fluent Bit（日志采集）
#
# 用法：
#   ./install.sh           # 部署指标监控
#   ./install.sh --logs    # 部署指标监控 + 日志采集
#   ./install.sh --logs-only  # 仅部署日志采集（假设指标已部署）

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELM_DIR="$SCRIPT_DIR/helm"
CHART_DIR="$HELM_DIR/remote-kube-prometheus-stack-85.1.3"
VALUES="$HELM_DIR/values-prod.yaml"
NAMESPACE="monitoring"
RELEASE="kube-prometheus-stack"
INSTALL_LOGS=false
LOGS_ONLY=false

# 解析参数
for arg in "$@"; do
  case "$arg" in
    --logs) INSTALL_LOGS=true ;;
    --logs-only) LOGS_ONLY=true ;;
  esac
done

# ============================================
# 1. 部署指标监控（kube-prometheus-stack）
# ============================================
if [ "$LOGS_ONLY" = false ]; then
  echo "📦 安装 kube-prometheus-stack (Helm 方式)..."
  echo "   Chart: kube-prometheus-stack 85.1.3"
  echo "   Values: $VALUES"
  echo ""

  # 校验本地 chart 存在
  if [ ! -d "$CHART_DIR" ]; then
    echo "❌ 未找到离线 Chart 目录: $CHART_DIR"
    echo "   请先执行: helm pull prometheus-community/kube-prometheus-stack --version 85.1.3 --untar"
    exit 1
  fi

  # Helm 安装（升级或首次）
  helm upgrade --install "$RELEASE" "$CHART_DIR" \
    --namespace "$NAMESPACE" \
    --create-namespace \
    --values "$VALUES" \
    --timeout 10m \
    --wait
fi

# ============================================
# 2. 部署日志采集（VictoriaLogs + Fluent Bit）
# ============================================
if [ "$INSTALL_LOGS" = true ] || [ "$LOGS_ONLY" = true ]; then
  echo ""
  echo "📋 部署日志采集组件..."

  echo "   ├─ VictoriaLogs (日志存储)..."
  kubectl apply -f "$SCRIPT_DIR/victoria-logs/"

  echo "   ├─ Fluent Bit (日志采集 DaemonSet)..."
  kubectl apply -f "$SCRIPT_DIR/fluent-bit/"

  echo "   └─ Grafana VictoriaLogs 数据源..."
  kubectl apply -f "$SCRIPT_DIR/grafana/"
fi

# ============================================
# 3. 输出部署信息
# ============================================
echo ""
echo "✅ 部署完成！"
echo ""

if [ "$LOGS_ONLY" = false ]; then
  echo "📊 指标监控："
  echo "   Grafana:"
  echo "     http://monitor.czw-sre.internal       （需 hosts 指向 192.168.5.240）"
  echo "     http://<任一节点IP>:30002              （NodePort 直连）"
  echo "     默认账号: admin / admin123"
  echo ""
  echo "   Prometheus: http://prometheus-operated.monitoring:9090（集群内）"
  echo ""
fi

if [ "$INSTALL_LOGS" = true ] || [ "$LOGS_ONLY" = true ]; then
  echo "📝 日志采集："
  echo "   VictoriaLogs:  http://victoria-logs.monitoring:9428（集群内）"
  echo "   Fluent Bit:    DaemonSet 已部署至每个节点"
  echo ""
  echo "📝 Grafana 数据源："
  echo "   已自动注册 VictoriaLogs 数据源（需等待 Grafana 重启加载插件后生效）"
  echo "   在 Explore 中切换数据源为 VictoriaLogs 即可查询日志"
  echo "   查询语法: LogsQL（如 'error and namespace:mysql'）"
  echo ""
fi

echo "🔍 查看状态："
echo "   kubectl get pods -n monitoring"
echo "   kubectl get svc -n monitoring"
echo "   kubectl get daemonset -n monitoring"
echo ""

if [ "$LOGS_ONLY" = false ]; then
  echo "📝 首次访问请修改 Grafana 默认密码！"
fi
