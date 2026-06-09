# Deployment 模式 Redis 安装脚本
# 基于原生 Deployment（非 Operator），K8s 1.19+ 可用
# 单实例 standalone，仅 1 副本，RWO PVC
#
# 用法:
#   ./install.sh              # 安装全部资源

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
MANIFESTS="$SCRIPT_DIR/manifests"
CONF="$SCRIPT_DIR/conf"
NAMESPACE="redis-deployment"

echo "📦 部署 Deployment 模式 Redis (standalone)"
echo ""

# 创建命名空间
echo "📁 创建 namespace: $NAMESPACE"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# 应用所有 manifest
echo "📄 应用 manifests..."
for f in "$MANIFESTS"/*.yaml; do
  echo "   ├── $(basename "$f")"
  kubectl apply -f "$f"
done

# 等待就绪
echo ""
echo "⏳ 等待 Pod 就绪..."
kubectl wait --for=condition=ready pod -l app=redis-standalone -n "$NAMESPACE" --timeout=120s 2>/dev/null || {
  echo "⚠️ 等待超时，查看当前状态："
  kubectl get pods -n "$NAMESPACE"
}

echo ""
echo "✅ Deployment Redis 部署完成！"
echo ""
echo "📝 连接方式："
echo "   集群外: redis-cli -h <任一节点IP> -p 30007 -a 'redis@czw'"
echo "   集群内: redis-cli -h redis-standalone.${NAMESPACE}.svc.cluster.local -p 6379 -a 'redis@czw'"
echo ""
echo "🔍 查看状态："
echo "   kubectl get pods -n $NAMESPACE"
echo "   kubectl get pvc -n $NAMESPACE"
echo ""
echo "📊 验证："
echo "   redis-cli -h <节点IP> -p 30005 -a 'redis@czw' ping"
echo "   redis-cli -h <节点IP> -p 30005 -a 'redis@czw' SET test hello"
echo "   redis-cli -h <节点IP> -p 30005 -a 'redis@czw' GET test"