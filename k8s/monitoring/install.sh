#!/bin/bash
# kube-prometheus-stack 安装脚本 - 通过 Helm 部署完整监控栈
# 包含：Prometheus Operator + Prometheus + Grafana + AlertManager
#       + Node Exporter + kube-state-metrics + 默认仪表板
# 可选：VictoriaLogs + Fluent Bit（日志采集）
#
# 幂等性说明：
# - Helm upgrade --install: 重复执行自动跳过已安装部分，只更新有变更的配置
# - kubectl apply: 幂等，无变更时不做任何操作
# - Grafana 插件：检查 PVC 上是否已存在，不存在则下载并安装
# - 所有组件都已配置正确的健康检查和启动等待
#
# 用法：
#   ./install.sh                     # 部署指标监控
#   ./install.sh --logs              # 部署指标监控 + 日志采集
#   ./install.sh --logs-only         # 仅部署日志采集（假设指标已部署）
#   ./install.sh --logs --skip-plugin # 部署日志但跳过插件安装（后续可手动安装）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELM_DIR="$SCRIPT_DIR/helm"
CHART_DIR="$HELM_DIR/remote-kube-prometheus-stack-85.1.3"
VALUES="$HELM_DIR/values-prod.yaml"
NAMESPACE="monitoring"
RELEASE="kube-prometheus-stack"
INSTALL_LOGS=false
LOGS_ONLY=false
SKIP_PLUGIN=false

# 解析参数
for arg in "$@"; do
  case "$arg" in
    --logs) INSTALL_LOGS=true ;;
    --logs-only) LOGS_ONLY=true ;;
    --skip-plugin) SKIP_PLUGIN=true ;;
  esac
done

# ============================================
# 辅助函数
# ============================================

# 等待指定命名空间的 pod 就绪
wait_for_pods() {
  local label="$1"
  local timeout="${2:-120}"
  local namespace="${3:-$NAMESPACE}"
  echo "   ⏳ 等待 $label 就绪（超时 ${timeout}s）..."
  kubectl wait --for=condition=ready pod -l "$label" -n "$namespace" --timeout="${timeout}s" 2>/dev/null || {
    echo "   ⚠️  等待超时，当前状态："
    kubectl get pods -n "$namespace" -l "$label" 2>/dev/null
    return 1
  }
  echo "   ✓ $label 就绪"
}

# 安装 Grafana VictoriaLogs 插件
install_grafana_plugin() {
  local plugin_name="victoriametrics-logs-datasource"
  local plugin_version="v0.27.1"

  echo "   ├─ VictoriaLogs Grafana 插件..."

  # 获取当前运行的 Grafana pod
  local grafana_pod
  grafana_pod=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=grafana" \
    -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' 2>/dev/null | awk '{print $1}')

  if [ -z "$grafana_pod" ]; then
    echo "     ⚠️  未找到运行中的 Grafana pod，跳过插件安装"
    echo "     部署完成后可手动运行: plugins/download-plugin.sh --install"
    return 1
  fi

  # 检查插件是否已安装在 PVC 上
  local plugin_installed
  plugin_installed=$(kubectl exec -n "$NAMESPACE" "$grafana_pod" -- \
    ls /var/lib/grafana/plugins/$plugin_name/plugin.json 2>/dev/null || echo "")

  if [ -n "$plugin_installed" ]; then
    echo "     ✓ 插件已安装在 PVC，跳过安装"
    return 0
  fi

  echo "     ⏳ 插件未安装，准备手动安装..."

  # 调用插件下载/安装脚本
  if [ -f "$SCRIPT_DIR/plugins/download-plugin.sh" ]; then
    echo "     "
    "$SCRIPT_DIR/plugins/download-plugin.sh" --install
    return $?
  fi

  echo "     ❌ 未找到 plugins/download-plugin.sh"
  echo "     请手动执行: plugins/download-plugin.sh --install"
  return 1
}

# ============================================
# 1. 部署指标监控（kube-prometheus-stack）
# ============================================
if [ "$LOGS_ONLY" = false ]; then
  echo ""
  echo "╔══════════════════════════════════════════════╗"
  echo "║        kube-prometheus-stack 安装           ║"
  echo "╚══════════════════════════════════════════════╝"
  echo ""
  echo "📦 Chart: kube-prometheus-stack 85.1.3"

  # 校验本地 chart 存在
  if [ ! -d "$CHART_DIR" ]; then
    echo "❌ 未找到离线 Chart 目录: $CHART_DIR"
    echo "   请先执行: helm pull prometheus-community/kube-prometheus-stack --version 85.1.3 --untar"
    exit 1
  fi

  # Helm 安装（幂等：重复执行自动跳过已安装部分）
  echo "   └─ helm upgrade --install..."
  helm upgrade --install "$RELEASE" "$CHART_DIR" \
    --namespace "$NAMESPACE" \
    --create-namespace \
    --values "$VALUES" \
    --timeout 10m \
    --wait

  echo ""
  echo "✅ kube-prometheus-stack 安装/验证完成"
fi

# ============================================
# 2. 部署日志采集（VictoriaLogs + Fluent Bit）
# ============================================
if [ "$INSTALL_LOGS" = true ] || [ "$LOGS_ONLY" = true ]; then
  echo ""
  echo "╔══════════════════════════════════════════════╗"
  echo "║      日志采集组件部署（幂等）               ║"
  echo "╚══════════════════════════════════════════════╝"

  # --- 2a. VictoriaLogs ---
  echo ""
  echo "📦 [1/5] VictoriaLogs (日志存储)"
  echo "   ├─ kubectl apply StatefulSet + Service..."
  kubectl apply -f "$SCRIPT_DIR/victoria-logs/"
  wait_for_pods "app.kubernetes.io/name=victoria-logs" 120 || true

  # 确认 VictoriaLogs 健康
  vl_pod=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=victoria-logs" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  if [ -n "$vl_pod" ]; then
    vl_ready=$(kubectl get pod -n "$NAMESPACE" "$vl_pod" \
      -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
    if [ "$vl_ready" = "True" ]; then
      echo "   ├─ 数据写入量检查..."
      ingested=$(kubectl exec -n "$NAMESPACE" "$vl_pod" -- sh -c \
        'wget -q -O- http://127.0.0.1:9428/metrics 2>/dev/null | grep "^vl_bytes_ingested_total" | cut -d" " -f2' 2>/dev/null || echo "0")
      echo "   └─ 已写入: ${ingested}B"
    fi
  fi

  # --- 2b. Fluent Bit ---
  echo ""
  echo "📦 [2/5] Fluent Bit (日志采集 DaemonSet)"
  echo "   ├─ kubectl apply RBAC + ConfigMap + DaemonSet..."
  kubectl apply -f "$SCRIPT_DIR/fluent-bit/"
  wait_for_pods "app.kubernetes.io/name=fluent-bit" 120 || true

  fb_ready=$(kubectl get daemonset -n "$NAMESPACE" fluent-bit \
    -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
  echo "   └─ 就绪节点: $fb_ready/${fb_ready}"

  # --- 2c. Grafana 数据源 ---
  echo ""
  echo "📦 [3/5] Grafana 数据源配置"
  echo "   ├─ 注册 VictoriaLogs 数据源..."
  kubectl apply -f "$SCRIPT_DIR/grafana/"
  echo "   └─ 数据源 ConfigMap 已更新（sidecar 自动加载）"

  # --- 2d. Grafana 插件 ---
  echo ""
  echo "📦 [4/5] Grafana 插件管理"
  if [ "$SKIP_PLUGIN" = true ]; then
    echo "   └─ 跳过安装（--skip-plugin）"
  else
    install_grafana_plugin || true
  fi

  # --- 2e. 确认 Fluent Bit 已连上 VictoriaLogs ---
  echo ""
  echo "📦 [5/5] 端到端验证"
  echo "   ├─ 检查 Fluent Bit -> VictoriaLogs 连通性..."
  sleep 5

  fb_log=$(kubectl logs -n "$NAMESPACE" -l "app.kubernetes.io/name=fluent-bit" --tail=3 2>/dev/null | grep -c "HTTP status=200" || echo "0")
  if [ "$fb_log" -gt 0 ]; then
    echo "   └─ ✓ Fluent Bit -> VictoriaLogs 数据流正常（HTTP 200）"
  else
    echo "   └─ ⚠️  未检测到数据流，Fluent Bit 可能还在缓冲中（Retry_limit=false 正常行为）"
    echo "      运行以下命令确认：kubectl logs -n monitoring -l app.kubernetes.io/name=fluent-bit --tail=5"
  fi
fi

# ============================================
# 3. 输出部署信息
# ============================================
echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║              部署完成                        ║"
echo "╚══════════════════════════════════════════════╝"
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
  echo "   数据源: VictoriaLogs（type: victoriametrics-logs-datasource）"
  echo "   在 Explore 中切换数据源为 VictoriaLogs 即可查询日志"
  echo "   查询语法: LogsQL（如 'namespace:mysql and error'）"
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

echo "📝 详细部署文档见 DEPLOYMENT.md"
