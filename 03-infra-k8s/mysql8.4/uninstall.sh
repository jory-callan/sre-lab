#!/bin/bash
# MySQL 8.4 卸载脚本
#
# 用法:
#   ./uninstall.sh                  # 卸载 standalone（默认）
#   ./uninstall.sh standalone       # 同上
#   ./uninstall.sh cluster          # 卸载 cluster
#   ./uninstall.sh all              # 卸载所有 MySQL CR + operator

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPERATOR_NS="mysql-operator"
MYSQL_NS="mysql"
RELEASE="ps-operator"

MODE="${1:-standalone}"
VALID_MODES="standalone cluster all"
if ! echo "$VALID_MODES" | grep -qw "$MODE"; then
  echo "❌ 无效模式: $MODE"
  echo "   用法: $0 [standalone|cluster|all]"
  exit 1
fi

echo "🗑️  卸载模式: $MODE"
echo ""

uninstall_cr() {
  local mode="$1"
  local cr_dir="$SCRIPT_DIR/operator/$mode"

  echo "🗑️  删除 $mode CR..."
  if [ -d "$cr_dir" ]; then
    # 删除 CR（按目录下文件顺序反向删除）
    for f in $(ls -r "$cr_dir/" 2>/dev/null); do
      kubectl delete -f "$cr_dir/$f" --grace-period=30 2>/dev/null || true
    done
  fi

  # 等待 Pod 终止
  echo "⏳ 等待 Pod 终止..."
  sleep 10

  # 删除 PVC（保留数据的安全删除）
  echo "🗑️  删除 PVC..."
  kubectl get pvc -n "$MYSQL_NS" 2>/dev/null | grep -E "^mysql-${mode}" | awk '{print $1}' | xargs -r kubectl delete pvc -n "$MYSQL_NS" --grace-period=10 2>/dev/null || true
}

case "$MODE" in
  standalone)
    uninstall_cr "standalone"
    # 保留 operator
    echo "✅ Standalone CR 已删除，operator 保留"
    ;;
  cluster)
    uninstall_cr "cluster"
    echo "✅ Cluster CR 已删除，operator 保留"
    ;;
  all)
    uninstall_cr "standalone" || true
    uninstall_cr "cluster" || true

    # 删除公共 Secret
    kubectl delete -f "$SCRIPT_DIR/operator/common/" 2>/dev/null || true

    # 删除 operator
    if helm list -n "$OPERATOR_NS" 2>/dev/null | grep -qw "$RELEASE"; then
      echo "🗑️  卸载 ps-operator..."
      helm uninstall "$RELEASE" -n "$OPERATOR_NS" 2>/dev/null || true
    fi

    echo "🗑️  删除命名空间..."
    kubectl delete namespace "$MYSQL_NS" --grace-period=30 2>/dev/null || true
    kubectl delete namespace "$OPERATOR_NS" --grace-period=30 2>/dev/null || true

    echo "✅ MySQL 已完全卸载"
    ;;
esac
