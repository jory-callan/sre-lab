#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASSWORD="${1:-redis@czw}"

echo "=============================="
echo "redis-core 部署"
echo "=============================="

# ── 1. Operator（命名空间: operators）──
echo ""
echo "[1/4] 部署 Operator → operators 命名空间"
kubectl create ns operators --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "$SCRIPT_DIR/operator/spotahome/00-operator.yaml"
kubectl wait --for=condition=available -n operators deployment/redisoperator --timeout=120s
echo "       Operator 就绪"

# ── 2. 命名空间 redis ──
echo ""
echo "[2/4] 创建 redis 命名空间 + 公共 Secret"
kubectl create ns redis --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "$SCRIPT_DIR/cr/common/secret.yaml"
echo "       完成"

# ── 3. RedisFailover CR ──
echo ""
echo "[3/4] 部署 redis-core CR + Service + 备份"
kubectl apply -f "$SCRIPT_DIR/cr/sentinel-ha/redis-failover.yaml"
kubectl apply -f "$SCRIPT_DIR/cr/sentinel-ha/service-external.yaml"
kubectl apply -f "$SCRIPT_DIR/cr/sentinel-ha/backup-cronjob.yaml"
echo "       完成"

# ── 4. 等待就绪 ──
echo ""
echo "[4/4] 等待 Pod 就绪..."
for i in $(seq 1 60); do
  READY=$(kubectl get pods -n redis \
    -l redisfailovers.databases.spotahome.com/name=redis-core \
    -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
  ALL_READY=$(echo "$READY" | tr ' ' '\n' | grep -v "True" | wc -l | tr -d ' ')
  COUNT=$(echo "$READY" | wc -w | tr -d ' ')
  if [ "$ALL_READY" = "0" ] && [ "$COUNT" -ge 6 ]; then
    echo "       所有 Pod 已就绪！"
    kubectl get pods -n redis -o wide
    break
  fi
  printf "\r       等待中... %ds" $((i * 2))
  sleep 2
done

echo ""
echo "=============================="
echo "部署完成"
echo "=============================="
echo ""
echo "连接信息:"
echo "  集群内: redis://:${PASSWORD}@rfrm-redis-core.redis.svc:6379"
echo "  外部:   redis://:${PASSWORD}@<节点IP>:30207"
echo ""

# 快速验证
echo "--- 快速验证 ---"
MASTER=$(kubectl get pods -n redis -l redisfailovers-role=master -o name 2>/dev/null | head -1)
echo "  Master: ${MASTER#pod/}"
kubectl exec -n redis "${MASTER#pod/}" -- redis-cli -a "$PASSWORD" --no-auth-warning PING 2>/dev/null || echo "  (等待就绪)"
