#!/bin/bash
set -euo pipefail

# spotahome/redis-operator 一键部署脚本
# 用法: ./install.sh [namespace] [password]
# 默认: namespace=redis-spotahome, password=redis@czw

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NAMESPACE="${1:-redis-spotahome}"
PASSWORD="${2:-redis@czw}"

echo "=============================="
echo "spotahome/redis-operator 部署"
echo "=============================="
echo "命名空间: $NAMESPACE"
echo ""

# Step 1: 创建命名空间
kubectl create ns "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
echo "[1/4] 命名空间已就绪"

# Step 2: 创建密码 Secret
kubectl create secret generic redis-auth \
  -n "$NAMESPACE" \
  --from-literal=password="$PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -
echo "[2/4] 密码 Secret 已创建"

# Step 3: 部署 Operator (CRD + RBAC + Deployment)
kubectl apply -f "$SCRIPT_DIR/00-operator.yaml"
echo "[3/4] Operator 已部署"

# Step 4: 创建 RedisFailover CR
# 注意：CR 中的密码 Secret 名必须与 Step 2 一致
kubectl apply -f "$SCRIPT_DIR/01-redisfailover-cr.yaml"
echo "[4/4] RedisFailover CR 已创建"

echo ""
echo "=============================="
echo "等待 Pod 就绪..."
echo "=============================="

# 等待 operator pod
kubectl wait --for=condition=available -n "$NAMESPACE" deployment/redisoperator --timeout=120s 2>/dev/null || true

# 等待 Redis pods + Sentinel pods
echo "等待 Redis + Sentinel Pod..."
KUBECTL_RETRY=0
while [ $KUBECTL_RETRY -lt 30 ]; do
  READY=$(kubectl get pods -n "$NAMESPACE" \
    -l redisfailovers.databases.spotahome.com/name=redisfailover-ha \
    -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
  ALL_READY=$(echo "$READY" | tr ' ' '\n' | grep -v "True" | wc -l | tr -d ' ')
  if [ "$ALL_READY" = "0" ] && [ -n "$READY" ]; then
    echo "所有 Pod 已就绪！"
    break
  fi
  echo "等待中... (${KUBECTL_RETRY}s)"
  sleep 5
  KUBECTL_RETRY=$((KUBECTL_RETRY + 5))
done

echo ""
echo "=============================="
echo "部署完成 — 三步验证"
echo "=============================="
echo ""

MASTER_POD=$(kubectl get pods -n "$NAMESPACE" -l redisfailovers.databases.spotahome.com/name=redisfailover-ha -o name 2>/dev/null | head -1)

echo "1/3  PING"
kubectl exec -n "$NAMESPACE" "${MASTER_POD#pod/}" -- redis-cli -a "$PASSWORD" PING 2>/dev/null

echo "2/3  SET/GET"
kubectl exec -n "$NAMESPACE" "${MASTER_POD#pod/}" -- redis-cli -a "$PASSWORD" SET deploy:test "ok" 2>/dev/null
kubectl exec -n "$NAMESPACE" "${MASTER_POD#pod/}" -- redis-cli -a "$PASSWORD" GET deploy:test 2>/dev/null

echo "3/3  Sentinel 确认 master"
kubectl exec -n "$NAMESPACE" deployment/rfs-redisfailover-ha -- redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster 2>/dev/null

echo ""
echo "连接信息:"
echo "  集群内: redis://:${PASSWORD}@rfrm-redisfailover-ha.${NAMESPACE}.svc:6379"
echo "  外部:   redis://:${PASSWORD}@<节点IP>:30206"