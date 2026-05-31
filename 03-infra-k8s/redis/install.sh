#!/bin/bash
# Redis 安装脚本 - 通过 manifests 部署单实例 Redis

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="redis"

echo "📦 安装 Redis..."

# 按依赖顺序创建资源
kubectl apply -f "$SCRIPT_DIR/manifests/namespace.yaml"
kubectl apply -f "$SCRIPT_DIR/manifests/secret.yaml"
kubectl apply -f "$SCRIPT_DIR/manifests/pvc.yaml"
kubectl apply -f "$SCRIPT_DIR/manifests/deployment.yaml"
kubectl apply -f "$SCRIPT_DIR/manifests/service.yaml"

echo ""
echo "✅ Redis 安装完成！"
echo ""
echo "📝 连接方式："
echo "   集群外: redis-cli -h <任一节点IP> -p 30003 -a 'redis@czw'"
echo "   集群内: redis-cli -h redis.redis.svc.cluster.local -p 6379 -a 'redis@czw'"
echo ""
echo "🔍 查看状态："
echo "   kubectl get pods -n redis"
echo "   kubectl get svc -n redis"
echo ""
echo "⚠️  请修改默认密码！"
echo "   kubectl edit secret redis-auth -n redis"
echo "   （修改后需重启 Pod: kubectl rollout restart -n redis deploy/redis）"
