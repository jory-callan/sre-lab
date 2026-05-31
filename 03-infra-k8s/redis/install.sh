#!/bin/bash
# Redis 安装脚本 - 部署 redis-operator + 创建 Redis standalone 实例
#
# 流程：
#   1. 安装 redis-operator（Helm Chart，含 CRDs）
#   2. 等待 operator Pod 就绪
#   3. 创建 Redis 实例 CR（standalone 模式）
#   4. 创建外部访问 NodePort Service

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELM_DIR="$SCRIPT_DIR/helm"
CHART_DIR="$HELM_DIR/remote-redis-operator-0.24.0"
VALUES="$HELM_DIR/values-prod.yaml"
OPERATOR_NS="redis-operator"
REDIS_NS="redis"

echo "📦 步骤 1/3：安装 redis-operator..."
echo "   Chart: redis-operator 0.24.0"
echo "   Namespace: $OPERATOR_NS"

# 校验离线 Chart 存在
if [ ! -d "$CHART_DIR" ]; then
  echo "❌ 未找到离线 Chart 目录: $CHART_DIR"
  exit 1
fi

# 安装 operator
helm upgrade --install redis-operator "$CHART_DIR" \
  --namespace "$OPERATOR_NS" \
  --create-namespace \
  --values "$VALUES" \
  --timeout 5m \
  --wait

echo ""
echo "📦 步骤 2/3：创建 Redis standalone 实例..."

# 先创建命名空间，再应用 CR
kubectl create namespace "$REDIS_NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "$SCRIPT_DIR/operator/"

# 等待 Redis 实例就绪
echo ""
echo "⏳ 等待 Redis 实例就绪..."
sleep 10
kubectl wait --for=condition=Ready --timeout=120s \
  -n "$REDIS_NS" \
  redis/redis-standalone 2>/dev/null || echo "   （CR 状态等待超时，请手动检查 Pod 状态）"

echo ""
echo "✅ Redis 安装完成！"
echo ""
echo "📝 连接方式："
echo "   集群外: redis-cli -h <任一节点IP> -p 30003 -a 'redis@czw'"
echo "   集群内: redis-cli -h redis-standalone.redis.svc.cluster.local -p 6379 -a 'redis@czw'"
echo ""
echo "🔍 查看状态："
echo "   kubectl get pods -n redis-operator"
echo "   kubectl get pods -n redis"
echo "   kubectl get redis -n redis"
echo ""
echo "⚠️  请修改默认密码！"
echo "   kubectl edit secret redis-auth -n redis"
echo "   （修改后需重启 Pod: kubectl delete pod -n redis -l app=redis-standalone）"
