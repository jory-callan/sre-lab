#!/bin/bash
# kube-prometheus-stack 安装脚本 - 通过 Helm 部署完整监控栈
# 包含：Prometheus Operator + Prometheus + Grafana + AlertManager
#       + Node Exporter + kube-state-metrics + 默认仪表板

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELM_DIR="$SCRIPT_DIR/helm"
CHART_DIR="$HELM_DIR/remote-kube-prometheus-stack-85.1.3"
VALUES="$HELM_DIR/values-prod.yaml"
NAMESPACE="monitoring"
RELEASE="kube-prometheus-stack"

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

echo ""
echo "✅ kube-prometheus-stack 安装完成！"
echo ""
echo "📊 组件访问："
echo "   Grafana:"
echo "     http://monitor.czw-sre.internal       （需 hosts 指向 192.168.5.240）"
echo "     http://<任一节点IP>:30002              （NodePort 直连）"
echo "     默认账号: admin / admin123"
echo ""
echo "   Prometheus: http://prometheus-operated.monitoring:9090（集群内）"
echo ""
echo "🔍 查看状态："
echo "   kubectl get pods -n monitoring"
echo "   kubectl get svc -n monitoring"
echo ""
echo "📝 首次访问请修改 Grafana 默认密码！"
