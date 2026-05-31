#!/bin/bash
# MySQL 8.4 安装脚本（基于 Percona PS Operator）
#
# 用法:
#   ./install.sh                  # 安装 operator + standalone（默认）
#   ./install.sh standalone       # 同上
#   ./install.sh cluster          # 安装 operator(已装则跳过) + InnoDB Cluster（3节点）
#
# 注意: standalone 和 cluster 是互斥的，不能同时部署
#       如果切换模式，先 ./uninstall.sh <当前模式> 清理

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELM_DIR="$SCRIPT_DIR/helm"
CHART_DIR="$HELM_DIR/remote-ps-operator-1.1.0"
VALUES="$HELM_DIR/values-prod.yaml"
OPERATOR_NS="mysql-operator"
MYSQL_NS="mysql"
RELEASE="ps-operator"

# 参数检测
MODE="${1:-standalone}"
VALID_MODES="standalone cluster"
if ! echo "$VALID_MODES" | grep -qw "$MODE"; then
  echo "❌ 无效模式: $MODE"
  echo "   用法: $0 [standalone|cluster]"
  exit 1
fi

echo "📦 部署模式: $MODE"
echo ""

# ============================================================
# 安装 operator（只装一次）
# ============================================================
install_operator() {
  if helm list -n "$OPERATOR_NS" 2>/dev/null | grep -qw "$RELEASE"; then
    echo "✅ ps-operator 已安装，跳过"
    return
  fi

  echo "📦 安装 ps-operator..."
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
  kubectl rollout status deployment/ps-operator -n "$OPERATOR_NS" --timeout=120s
}

# ============================================================
# 安装 MySQL 实例（按模式）
# ============================================================
install_instance() {
  local mode="$1"
  local cr_dir="$SCRIPT_DIR/operator/$mode"

  # 确保命名空间存在
  kubectl create namespace "$MYSQL_NS" --dry-run=client -o yaml | kubectl apply -f -

  # 应用公共资源（Secret）
  kubectl apply -f "$SCRIPT_DIR/operator/common/"

  # 应用模式专属 CR
  if [ -d "$cr_dir" ]; then
    # 先 apply CR，再 apply 外部 Service
    kubectl apply -f "$cr_dir/"
  else
    echo "❌ 未找到模式目录: $cr_dir"
    exit 1
  fi

  # 等待就绪
  echo ""
  echo "⏳ 等待 MySQL ($mode) 就绪..."
  sleep 10

  # 根据模式显示输出
  case "$mode" in
    standalone)
      echo ""
      echo "✅ MySQL Standalone 部署完成！"
      echo ""
      echo "📝 连接方式："
      echo "   集群外: mysql -h <任一节点IP> -P 30005 -u root -p'mysql@czw'"
      echo "   集群内: mysql -h mysql-standalone-primary.mysql.svc.cluster.local -u root -p'mysql@czw'"
      echo "   密码: mysql@czw"
      echo ""
      echo "🔍 查看状态："
      echo "   kubectl get perconaservermysql -n $MYSQL_NS"
      echo "   kubectl get pods -n $MYSQL_NS"
      ;;
    cluster)
      echo ""
      echo "✅ MySQL InnoDB Cluster 部署完成！"
      echo ""
      echo "📝 连接方式："
      echo "   集群外(主库): mysql -h <任一节点IP> -P 30005 -u root -p'mysql@czw'"
      echo "   集群内(主库): mysql -h mysql-cluster-haproxy.mysql.svc.cluster.local -u root -p'mysql@czw'"
      echo "   集群内(只读): mysql -h mysql-cluster-haproxy.mysql.svc.cluster.local -P 3307 -u root -p'mysql@czw'"
      echo "   密码: mysql@czw"
      echo ""
      echo "⚠️  InnoDB Cluster 需要 3 个 MySQL Pod 全部就绪后才可用"
      echo "   kubectl get pods -n $MYSQL_NS -w"
      echo ""
      echo "📌 检查集群状态："
      echo "   kubectl exec -n $MYSQL_NS mysql-cluster-mysql-0 -- mysqlsh --sql -e \"SELECT * FROM performance_schema.replication_group_members;\""
      ;;
  esac

  echo ""
  echo "📊 当前 MySQL 实例："
  kubectl get perconaservermysql -n "$MYSQL_NS" 2>/dev/null || true
}

install_operator
install_instance "$MODE"

echo ""
echo "✅ 部署完成！"
