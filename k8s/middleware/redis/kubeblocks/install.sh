#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="redis"
CLUSTER_NAME="redis-kb"
PASSWORD="redis@czw"

echo "=============================="
echo "Redis Cluster (KubeBlocks) 部署"
echo "=============================="
echo ""

# ── 1. 创建命名空间 ──
echo "[1/3] 创建命名空间"
kubectl create ns "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
echo "       完成"

# ── 2. 创建集群 ──
echo ""
echo "[2/3] 创建 Redis Cluster CR（1主2从+3哨兵）"
kubectl apply -f "$SCRIPT_DIR/cluster.yaml"
echo "       完成"

# ── 3. 等待就绪 ──
echo ""
echo "[3/3] 等待集群就绪（约 3-5 分钟）..."
kubectl wait --for=condition=Available cluster/$CLUSTER_NAME -n "$NAMESPACE" --timeout=600s 2>/dev/null || echo "       等待超时，请手动检查: kubectl get cluster -n $NAMESPACE -w"

echo ""
echo "=============================="
echo "Redis 部署完成"
echo "=============================="
echo ""
echo "连接信息:"
echo "  集群内 (sentinel): redis-cli -h redis-kb-redis-sentinel.${NAMESPACE}.svc.cluster.local -p 26379"
echo "  集群内 (redis):    redis-cli -h redis-kb-redis.${NAMESPACE}.svc.cluster.local -p 6379 -a '${PASSWORD}'"
echo ""
echo "查看状态:"
echo "  kubectl get pods -n $NAMESPACE -l app.kubernetes.io/instance=$CLUSTER_NAME"
echo "  kubectl get cluster -n $NAMESPACE $CLUSTER_NAME -o wide"
echo ""
echo "验证:"
echo "  kubectl exec -n $NAMESPACE ${CLUSTER_NAME}-redis-0 -- redis-cli -a '${PASSWORD}' --no-auth-warning PING"
echo "  kubectl exec -n $NAMESPACE ${CLUSTER_NAME}-redis-0 -- redis-cli -a '${PASSWORD}' --no-auth-warning INFO replication"
