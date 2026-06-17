#!/usr/bin/env bash
set -euo pipefail

NS="${1:-redis-spotahome-v111}"
PASS="${2:-redis@czw}"

echo "=== spotahome/redis-operator v1.1.1 + Redis 5.0.8 - 验证 ==="
echo ""

echo "--- 1/5 PING ---"
kubectl exec -n "$NS" deployment/redisoperator-v111 -- redis-cli -a "$PASS" -h rfrm-redisfailover-ha PING 2>/dev/null

echo ""
echo "--- 2/5 SET/GET ---"
kubectl exec -n "$NS" deployment/redisoperator-v111 -- redis-cli -a "$PASS" -h rfrm-redisfailover-ha SET v111:test "ok" 2>/dev/null
kubectl exec -n "$NS" deployment/redisoperator-v111 -- redis-cli -a "$PASS" -h rfrm-redisfailover-ha GET v111:test 2>/dev/null

echo ""
echo "--- 3/5 Redis 版本 ---"
kubectl exec -n "$NS" rfr-redisfailover-ha-0 -- redis-server --version 2>/dev/null

echo ""
echo "--- 4/5 各 pod 角色 ---"
for i in 0 1 2; do
  ROLE=$(kubectl exec -n "$NS" rfr-redisfailover-ha-$i -- redis-cli -a "$PASS" ROLE 2>/dev/null | head -1)
  echo "  rfr-$i: $ROLE"
done

echo ""
echo "--- 5/5 Sentinel master ---"
kubectl exec -n "$NS" deployment/rfs-redisfailover-ha -- redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster 2>/dev/null

echo ""
echo "=== Pod 分布 ==="
kubectl get pods -n "$NS" -o wide