#!/bin/bash
# PostgreSQL 17 卸载脚本
#
# 用法:
#   ./uninstall.sh              # 卸载 standalone（默认）
#   ./uninstall.sh standalone   # 同上
#   ./uninstall.sh ha           # 卸载 HA
#   ./uninstall.sh all          # 卸载所有 PostgreSQL CR + operator

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPERATOR_NS="cnpg-system"
PG_NS="pg"
RELEASE="cnpg"

MODE="${1:-standalone}"
VALID_MODES="standalone ha all"
if ! echo "$VALID_MODES" | grep -qw "$MODE"; then
  echo "❌ 无效模式: $MODE"
  echo "   用法: $0 [standalone|ha|all]"
  exit 1
fi

echo "🗑️  卸载模式: $MODE"
echo ""

uninstall_cr() {
  local mode="$1"
  local cr_dir="$SCRIPT_DIR/operator/$mode"

  echo "🗑️  删除 $mode Cluster CR..."
  if [ -d "$cr_dir" ]; then
    for f in $(ls -r "$cr_dir/" 2>/dev/null); do
      kubectl delete -f "$cr_dir/$f" --grace-period=30 2>/dev/null || true
    done
  fi

  # 等待 Pod 终止
  echo "⏳ 等待 Pod 终止..."
  sleep 15

  # CNPG 使用 StatefulSet，需要删除 PVC
  echo "🗑️  删除 PVC..."
  if [ "$mode" = "ha" ]; then
    kubectl get pvc -n "$PG_NS" 2>/dev/null | grep "^pg-ha" | awk '{print $1}' | xargs -r kubectl delete pvc -n "$PG_NS" --grace-period=10 2>/dev/null || true
  else
    kubectl get pvc -n "$PG_NS" 2>/dev/null | grep "^pg-standalone" | awk '{print $1}' | xargs -r kubectl delete pvc -n "$PG_NS" --grace-period=10 2>/dev/null || true
  fi
}

case "$MODE" in
  standalone)
    uninstall_cr "standalone"
    echo "✅ Standalone CR 已删除，operator 保留"
    ;;
  ha)
    uninstall_cr "ha"
    echo "✅ HA CR 已删除，operator 保留"
    ;;
  all)
    uninstall_cr "standalone" || true
    uninstall_cr "ha" || true

    # 删除公共 Secret
    kubectl delete -f "$SCRIPT_DIR/operator/common/" 2>/dev/null || true

    # 删除 operator
    if helm list -n "$OPERATOR_NS" 2>/dev/null | grep -qw "$RELEASE"; then
      echo "🗑️  卸载 cnpg operator..."
      helm uninstall "$RELEASE" -n "$OPERATOR_NS" 2>/dev/null || true
    fi

    echo "🗑️  删除命名空间..."
    kubectl delete namespace "$PG_NS" --grace-period=30 2>/dev/null || true
    kubectl delete namespace "$OPERATOR_NS" --grace-period=30 2>/dev/null || true

    echo "✅ PostgreSQL 已完全卸载"
    ;;
esac
