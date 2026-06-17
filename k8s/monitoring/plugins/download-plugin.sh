#!/bin/bash
# VictoriaLogs Grafana 插件下载/安装脚本
# 用于 k3s 内网环境，通过 gh-proxy 下载并安装到 Grafana PVC
#
# 用法：
#   ./download-plugin.sh             # 下载插件 zip 到本地缓存
#   ./download-plugin.sh --install   # 下载 + 安装到 Grafana PVC

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_VERSION="v0.27.1"
PLUGIN_NAME="victoriametrics-logs-datasource"
PLUGIN_ZIP="$SCRIPT_DIR/${PLUGIN_NAME}-${PLUGIN_VERSION}.tar.gz"
NAMESPACE="monitoring"

# gh-proxy 镜像地址（国内无法直接访问 github.com）
GH_PROXY="https://gh-proxy.com"
PLUGIN_URL="${GH_PROXY}/https://github.com/VictoriaMetrics/victorialogs-datasource/releases/download/${PLUGIN_VERSION}/${PLUGIN_NAME}-${PLUGIN_VERSION}.tar.gz"

download_plugin() {
  if [ -f "$PLUGIN_ZIP" ]; then
    echo "✓ 插件已缓存: $PLUGIN_ZIP ($(du -h "$PLUGIN_ZIP" | cut -f1))"
    return 0
  fi

  echo "⏳ 下载插件 ${PLUGIN_NAME}:${PLUGIN_VERSION}..."
  echo "   来源: $PLUGIN_URL"

  mkdir -p "$SCRIPT_DIR"
  curl -sL --connect-timeout 30 -o "$PLUGIN_ZIP" "$PLUGIN_URL"

  if [ ! -f "$PLUGIN_ZIP" ] || [ "$(stat -f%z "$PLUGIN_ZIP" 2>/dev/null || echo 0)" -lt 1000 ]; then
    echo "❌ 下载失败！请检查网络或 gh-proxy 是否可用"
    rm -f "$PLUGIN_ZIP"
    exit 1
  fi

  echo "✓ 下载完成: $(du -h "$PLUGIN_ZIP" | cut -f1)"
}

install_plugin() {
  echo ""
  echo "⏳ 检查 Grafana 状态..."

  # 等待 Grafana pod 就绪
  local grafana_pod=""
  for i in $(seq 1 30); do
    grafana_pod=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=grafana" \
      -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

    if [ -n "$grafana_pod" ]; then
      local ready=$(kubectl get pod -n "$NAMESPACE" "$grafana_pod" \
        -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
      if [ "$ready" = "True" ]; then
        break
      fi
    fi
    echo "   ⏳ 等待 Grafana 就绪... ($i/30)"
    sleep 5
  done

  if [ -z "$grafana_pod" ]; then
    echo "❌ Grafana pod 不可用，请先部署 Grafana"
    exit 1
  fi

  # 检查插件是否已安装
  local plugin_installed
  plugin_installed=$(kubectl exec -n "$NAMESPACE" "$grafana_pod" -- \
    ls /var/lib/grafana/plugins/${PLUGIN_NAME}/plugin.json 2>/dev/null || echo "")

  if [ -n "$plugin_installed" ]; then
    echo "✓ 插件已在 PVC 上，跳过安装"
    return 0
  fi

  # 下载插件（如果未缓存）
  if [ ! -f "$PLUGIN_ZIP" ]; then
    download_plugin
  fi

  echo "⏳ 复制插件到 Grafana pod..."

  # 解压到临时目录并复制到 pod
  local extract_dir
  extract_dir=$(mktemp -d)
  tar xzf "$PLUGIN_ZIP" -C "$extract_dir"

  kubectl cp "$extract_dir/${PLUGIN_NAME}" "monitoring/${grafana_pod}:/var/lib/grafana/plugins/${PLUGIN_NAME}"

  rm -rf "$extract_dir"

  # 验证
  local verify
  verify=$(kubectl exec -n "$NAMESPACE" "$grafana_pod" -- \
    ls /var/lib/grafana/plugins/${PLUGIN_NAME}/plugin.json 2>/dev/null || echo "")

  if [ -z "$verify" ]; then
    echo "❌ 插件复制失败"
    exit 1
  fi

  echo "✓ 插件已复制到 PVC"
  echo ""
  echo "⏳ 重启 Grafana 加载插件..."

  kubectl rollout restart -n "$NAMESPACE" deployment/kube-prometheus-stack-grafana
  kubectl rollout status -n "$NAMESPACE" deployment/kube-prometheus-stack-grafana --timeout=5m

  echo "✓ Grafana 重启完成，插件已加载"
}

# ============================================
# 主流程
# ============================================
case "${1:-}" in
  --install)
    download_plugin
    install_plugin
    ;;
  --help|-h)
    echo "用法: $0 [--install]"
    echo "  (无参数)  仅下载插件到本地缓存"
    echo "  --install 下载 + 安装到 Grafana PVC"
    exit 0
    ;;
  *)
    download_plugin
    ;;
esac

echo ""
echo "✅ 完成"
echo "   插件缓存: $PLUGIN_ZIP"
if [ -f "$PLUGIN_ZIP" ]; then
  echo "   大小: $(du -h "$PLUGIN_ZIP" | cut -f1)"
fi
