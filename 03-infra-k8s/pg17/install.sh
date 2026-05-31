#!/bin/bash
# PostgreSQL 17 安装脚本（基于 CloudNativePG Operator）
#
# 用法:
#   ./install.sh                  # 安装 operator + standalone（默认）
#   ./install.sh standalone       # 同上
#   ./install.sh ha               # 安装 operator(已装则跳过) + HA（3节点流复制）
#
# 注意: standalone 和 ha 是互斥的，不能同时部署在同一个 namespace
#       如果切换模式，先 ./uninstall.sh <当前模式> 清理

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELM_DIR="$SCRIPT_DIR/helm"
CHART_DIR="$HELM_DIR/remote-cloudnative-pg-0.28.2"
VALUES="$HELM_DIR/values-prod.yaml"
OPERATOR_NS="cnpg-system"
PG_NS="pg"
RELEASE="cnpg"

# 参数检测
MODE="${1:-standalone}"
VALID_MODES="standalone ha"
if ! echo "$VALID_MODES" | grep -qw "$MODE"; then
  echo "❌ 无效模式: $MODE"
  echo "   用法: $0 [standalone|ha]"
  exit 1
fi

echo "📦 部署模式: $MODE"
echo ""

# ============================================================
# 安装 operator（只装一次）
# ============================================================
install_operator() {
  if helm list -n "$OPERATOR_NS" 2>/dev/null | grep -qw "$RELEASE"; then
    echo "✅ cnpg operator 已安装，跳过"
    return
  fi

  echo "📦 安装 CloudNativePG operator..."
  if [ ! -d "$CHART_DIR" ]; then
    echo "❌ 未找到离线 Chart 目录: $CHART_DIR"
    exit 1
  fi

  helm upgrade --install "$RELEASE" "$CHART_DIR" \
    --namespace "$OPERATOR_NS" \
    --create-namespace \
    --values "$VALUES" \
    --timeout 5m \
    --wait

  echo "⏳ 等待 operator 就绪..."
  kubectl rollout status deployment/cnpg-controller-manager -n "$OPERATOR_NS" --timeout=120s
}

# ============================================================
# 安装 PostgreSQL 实例（按模式）
# ============================================================
install_instance() {
  local mode="$1"
  local cr_dir="$SCRIPT_DIR/operator/$mode"

  # 确保命名空间存在
  kubectl create namespace "$PG_NS" --dry-run=client -o yaml | kubectl apply -f -

  # 应用公共资源（Secret）
  kubectl apply -f "$SCRIPT_DIR/operator/common/"

  # 应用模式专属 CR
  if [ -d "$cr_dir" ]; then
    kubectl apply -f "$cr_dir/"
  else
    echo "❌ 未找到模式目录: $cr_dir"
    exit 1
  fi

  # 等待就绪
  echo ""
  echo "⏳ 等待 PostgreSQL ($mode) 就绪..."
  sleep 10

  case "$mode" in
    standalone)
      echo ""
      echo "✅ PostgreSQL Standalone 部署完成！"
      echo ""
      echo "📝 连接方式："
      echo "   集群外: psql -h <任一节点IP> -p 30006 -U postgres -d appdb"
      echo "   集群内: psql -h pg-standalone-rw.pg.svc.cluster.local -U postgres -d appdb"
      echo "   密码: pg@czw"
      echo ""
      echo "🔍 查看状态："
      echo "   kubectl get cluster -n $PG_NS"
      echo "   kubectl get pods -n $PG_NS"
      echo "   kubectl get pods -n $PG_NS -l cnpg.io/cluster=pg-standalone"
      ;;
    ha)
      echo ""
      echo "✅ PostgreSQL HA 部署完成！"
      echo ""
      echo "📝 连接方式："
      echo "   集群外(主库): psql -h <任一节点IP> -p 30006 -U postgres -d appdb"
      echo "   集群内(主库): psql -h pg-ha-rw.pg.svc.cluster.local -U postgres -d appdb"
      echo "   集群内(只读): psql -h pg-ha-ro.pg.svc.cluster.local -U postgres -d appdb"
      echo "   密码: pg@czw"
      echo ""
      echo "⚠️  等待所有 3 个实例就绪后集群才可用"
      echo "   kubectl get pods -n $PG_NS -w"
      echo ""
      echo "📌 查看集群状态："
      echo "   kubectl exec -n $PG_NS pg-ha-1 -- psql -c \"SELECT * FROM pg_stat_replication;\""
      ;;
  esac

  echo ""
  echo "📊 当前 PostgreSQL 集群："
  kubectl get cluster -n "$PG_NS" 2>/dev/null || true
}

install_operator
install_instance "$MODE"

echo ""
echo "✅ 部署完成！"
