#!/bin/bash
# kube-prometheus-stack 卸载脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="monitoring"
RELEASE="kube-prometheus-stack"

echo "🗑️  卸载 kube-prometheus-stack..."

# 卸载 Helm Release（保留 PVC）
helm uninstall "$RELEASE" --namespace "$NAMESPACE" 2>/dev/null || true

# 删除命名空间（包含所有 PVC）
kubectl delete namespace "$NAMESPACE" --ignore-not-found=true

# 清理 CRDs（kube-prometheus-stack 安装了大量 CRDs，如不需要可跳过）
# ⚠️ 注意：删除 CRD 会同时删除所有关联的 CR 资源
echo ""
echo "⚠️  CRD 未自动删除。如需清理："
echo "   kubectl delete crd -l app.kubernetes.io/instance=kube-prometheus-stack"
echo ""
echo "⚠️  PVC 已随命名空间删除。如需保留数据，请先备份。"
echo "✅ 卸载完成"
