#!/bin/bash
# MySQL 8.4 卸载脚本
#
# 用法:
#   ./uninstall.sh            # 卸载 standalone（默认）
#   ./uninstall.sh standalone # 同上
#   ./uninstall.sh cluster    # 卸载 cluster（含 operator）
#   ./uninstall.sh all        # 卸载全部

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MYSQL_NS="mysql"
OPERATOR_NS="mysql-operator"
OPERATOR_RELEASE="ps-operator"

MODE="${1:-standalone}"

case "$MODE" in
  standalone)
    echo "🗑️  卸载 MySQL Standalone..."

    for f in statefulset.yaml service.yaml configmap.yaml secret.yaml pvc.yaml; do
      [ -f "$SCRIPT_DIR/manifests/$f" ] && kubectl delete -f "$SCRIPT_DIR/manifests/$f" --grace-period=10 2>/dev/null || true
    done

    echo "🗑️  删除 PVC..."
    kubectl get pvc -n "$MYSQL_NS" 2>/dev/null | grep -E "^data-mysql-" | awk '{print $1}' | xargs -r kubectl delete pvc -n "$MYSQL_NS" --grace-period=10 2>/dev/null || true

    echo "✅ 已卸载"
    ;;

  cluster)
    echo "🗑️  卸载 MySQL InnoDB Cluster..."
    kubectl delete -f "$SCRIPT_DIR/operator/cluster/" --grace-period=30 2>/dev/null || true
    kubectl delete -f "$SCRIPT_DIR/operator/common/" 2>/dev/null || true

    echo "🗑️ 等待 Pod 终止..."
    sleep 15

    echo "🗑️  删除 PVC..."
    kubectl get pvc -n "$MYSQL_NS" 2>/dev/null | grep "cluster" | awk '{print $1}' | xargs -r kubectl delete pvc -n "$MYSQL_NS" --grace-period=10 2>/dev/null || true

    echo "🗑️  卸载 operator..."
    helm uninstall "$OPERATOR_RELEASE" -n "$OPERATOR_NS" 2>/dev/null || true
    kubectl delete namespace "$OPERATOR_NS" --grace-period=10 2>/dev/null || true

    echo "✅ 已卸载"
    ;;

  all)
    echo "🗑️  卸载全部 MySQL..."

    for f in statefulset.yaml service.yaml configmap.yaml secret.yaml pvc.yaml; do
      [ -f "$SCRIPT_DIR/manifests/$f" ] && kubectl delete -f "$SCRIPT_DIR/manifests/$f" --grace-period=10 2>/dev/null || true
    done

    kubectl delete -f "$SCRIPT_DIR/operator/cluster/" --grace-period=30 2>/dev/null || true
    kubectl delete -f "$SCRIPT_DIR/operator/common/" 2>/dev/null || true

    helm uninstall "$OPERATOR_RELEASE" -n "$OPERATOR_NS" 2>/dev/null || true

    kubectl get pvc -n "$MYSQL_NS" 2>/dev/null | awk '{print $1}' | xargs -r kubectl delete pvc -n "$MYSQL_NS" --grace-period=10 2>/dev/null || true
    kubectl delete namespace "$MYSQL_NS" --grace-period=10 2>/dev/null || true
    kubectl delete namespace "$OPERATOR_NS" --grace-period=10 2>/dev/null || true

    echo "✅ 已完全卸载"
    ;;
esac
