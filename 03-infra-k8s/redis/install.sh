#!/bin/bash
# Redis 安装脚本
#
# 用法:
#   ./install.sh                  # 安装 operator + standalone（默认）
#   ./install.sh standalone       # 同上
#   ./install.sh sentinel-ha      # 安装 operator(已装则跳过) + sentinel HA
#   ./install.sh cluster          # 安装 operator(已装则跳过) + cluster

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELM_DIR="$SCRIPT_DIR/helm"
CHART_DIR="$HELM_DIR/remote-redis-operator-0.24.0"
VALUES="$HELM_DIR/values-prod.yaml"
OPERATOR_NS="redis-operator"
REDIS_NS="redis"
RELEASE="redis-operator"

# 参数检测
MODE="${1:-standalone}"
VALID_MODES="standalone sentinel-ha cluster"
if ! echo "$VALID_MODES" | grep -qw "$MODE"; then
  echo "❌ 无效模式: $MODE"
  echo "   用法: $0 [standalone|sentinel-ha|cluster]"
  exit 1
fi

echo "📦 部署模式: $MODE"
echo ""

# ============================================================
# 安装 operator（只装一次）
# ============================================================
install_operator() {
  if helm list -n "$OPERATOR_NS" 2>/dev/null | grep -qw "$RELEASE"; then
    echo "✅ redis-operator 已安装，跳过"
    return
  fi

  echo "📦 安装 redis-operator..."
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
}

# ============================================================
# 安装 Redis 实例（按模式）
# ============================================================
install_instance() {
  local mode="$1"
  local cr_dir="$SCRIPT_DIR/operator/$mode"

  # 先确保命名空间存在
  kubectl create namespace "$REDIS_NS" --dry-run=client -o yaml | kubectl apply -f -

  # 应用公共资源（Secret 等）
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
  echo "⏳ 等待 Redis ($mode) 就绪..."
  sleep 10

  # 根据模式显示不同的输出
  case "$mode" in
    standalone)
      echo ""
      echo "✅ Redis Standalone 部署完成！"
      echo ""
      echo "📝 连接方式："
      echo "   集群外: redis-cli -h <任一节点IP> -p 30003 -a 'redis@czw'"
      echo "   集群内: redis-cli -h redis-standalone.redis.svc.cluster.local -p 6379 -a 'redis@czw'"
      echo "   密码: redis@czw"
      ;;
    sentinel-ha)
      echo ""
      echo "✅ Redis Sentinel HA 部署完成！"
      echo ""
      echo "📝 连接方式："
      echo "   Sentinel: <任一节点IP>:30004"
      echo "   主节点地址: redis-replication-0.redis-replication-headless.redis.svc.cluster.local:6379"
      echo "   密码: redis@czw"
      echo ""
      echo "⚠️  Sentinel 由 replication controller 自动管理，不单独创建 CR"
      echo "   查看: kubectl get pods -n redis -w"
      ;;
    cluster)
      echo ""
      echo "✅ Redis Cluster 部署完成！"
      echo ""
      echo "📝 连接方式："
      echo "   集群内: redis-cli -h redis-cluster.redis.svc.cluster.local -p 6379 -c -a 'redis@czw'"
      echo "   密码: redis@czw"
      echo ""
      echo "⚠️  注意：集群初始化需等待所有节点就绪（6 个实例）"
      echo "   kubectl get pods -n redis -w"
      ;;
  esac

  echo ""
  echo "🔍 查看状态："
  echo "   kubectl get pods -n $REDIS_NS"
  echo "   kubectl get $MODE_CRD -n $REDIS_NS"
}

# 模式对应的 CRD 类型
case "$MODE" in
  standalone)   MODE_CRD="redis" ;;
  sentinel-ha)  MODE_CRD="redisreplication" ;;
  cluster)      MODE_CRD="rediscluster" ;;
esac

install_operator
install_instance "$MODE"

echo ""
echo "📊 当前集群 Redis 实例："
kubectl get redis,redisreplication,redissentinel,rediscluster -n "$REDIS_NS" 2>/dev/null || true
