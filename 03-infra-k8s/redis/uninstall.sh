#!/bin/bash
# Redis 卸载脚本
#
# 用法:
#   ./uninstall.sh                  # 删除所有 Redis 实例 + operator
#   ./uninstall.sh standalone       # 只删 standalone，保留 operator
#   ./uninstall.sh sentinel-ha      # 只删 sentinel-ha，保留 operator
#   ./uninstall.sh cluster          # 只删 cluster，保留 operator

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPERATOR_NS="redis-operator"
REDIS_NS="redis"

MODE="${1:-all}"
VALID_MODES="all standalone sentinel-ha cluster"
if ! echo "$VALID_MODES" | grep -qw "$MODE"; then
  echo "❌ 无效参数: $MODE"
  echo "   用法: $0 [all|standalone|sentinel-ha|cluster]"
  exit 1
fi

echo "🗑️  卸载模式: $MODE"
echo ""

# ============================================================
# 删除 Redis 实例 CR
# ============================================================
delete_instance() {
  local mode="$1"
  local cr_dir="$SCRIPT_DIR/operator/$mode"

  if [ -d "$cr_dir" ]; then
    echo "→ 删除 $mode CR..."
    kubectl delete -f "$cr_dir/" 2>/dev/null || true
  fi
}

case "$MODE" in
  all)
    delete_instance standalone
    delete_instance sentinel-ha
    delete_instance cluster
    kubectl delete namespace "$REDIS_NS" --ignore-not-found 2>/dev/null || true
    echo ""
    echo "🗑️  卸载 redis-operator..."
    helm uninstall redis-operator --namespace "$OPERATOR_NS" 2>/dev/null || true
    kubectl delete namespace "$OPERATOR_NS" --ignore-not-found 2>/dev/null || true
    echo ""
    echo "⚠️  如需清理 CRD："
    echo "   kubectl delete crd -l app.kubernetes.io/managed-by=redis-operator"
    ;;
  standalone)
    delete_instance standalone
    # 如果只剩 standalone 一个模式了就顺便清 common
    if ! ls "$SCRIPT_DIR/operator/"*/ -d 2>/dev/null | grep -v common >/dev/null 2>&1; then
      kubectl delete -f "$SCRIPT_DIR/operator/common/" 2>/dev/null || true
    fi
    echo ""
    echo "✅ standalone 实例已删除，operator 保留"
    ;;
  sentinel-ha)
    delete_instance sentinel-ha
    echo ""
    echo "✅ sentinel-ha 实例已删除，operator 保留"
    ;;
  cluster)
    delete_instance cluster
    echo ""
    echo "✅ cluster 实例已删除，operator 保留"
    ;;
esac

echo ""
echo "📊 剩余 Redis 实例："
kubectl get redis,redisreplication,redissentinel,rediscluster -n "$REDIS_NS" 2>/dev/null || echo "   (无)"
