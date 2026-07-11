#!/bin/bash
# Redis 单实例快速验证

set -euo pipefail

echo "═══ Redis 单实例快速验证 ═══"

# 1. 创建 namespace
kubectl create namespace redis-test --dry-run=client -o yaml | kubectl apply -f -

# 2. 部署单实例
echo "→ 部署单实例 Redis..."
kubectl apply -f redis-single.yaml

# 3. 等待 Pod 就绪
echo "→ 等待 Pod 就绪..."
kubectl wait pod -l app.kubernetes.io/name=redis-single \
  -n redis-test --for=condition=Ready --timeout=120s

# 4. 验证连接
echo "→ 验证连接..."
POD=$(kubectl -n redis-test get pod -l app.kubernetes.io/name=redis-single -o name | head -1)
kubectl -n redis-test exec "$POD" -- redis-cli PING

# 5. 验证读写
echo "→ 读写测试..."
kubectl -n redis-test exec "$POD" -- redis-cli SET hello world
kubectl -n redis-test exec "$POD" -- redis-cli GET hello

echo ""
echo "✓ 单实例验证通过"
echo ""
echo "清理: kubectl delete -f redis-single.yaml"
