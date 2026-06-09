#!/bin/bash
# Helm 模式 Redis 安装脚本
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
NAMESPACE="${1:-redis-deployment}"
RELEASE="${2:-redis-standalone}"

echo "📦 部署 Redis (Helm chart)"
echo "   Release:  $RELEASE"
echo "   Namespace: $NAMESPACE"
echo ""

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install "$RELEASE" "$SCRIPT_DIR" \
  --namespace "$NAMESPACE" \
  --create-namespace \
  --timeout 3m \
  --wait

echo ""
echo "✅ 部署完成！"
echo ""
echo "📝 连接方式："
echo "   集群外: redis-cli -h <节点IP> -p 30007 -a 'redis@czw'"
echo "   集群内: redis-cli -h ${RELEASE}.${NAMESPACE}.svc.cluster.local -p 6379 -a 'redis@czw'"
echo ""
echo "🔍 验证："
echo "   redis-cli -h <节点IP> -p 30007 -a 'redis@czw' ping"