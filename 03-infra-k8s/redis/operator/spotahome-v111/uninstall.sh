#!/usr/bin/env bash
set -euo pipefail

NS="${1:-redis-spotahome-v111}"

echo "=== Uninstalling spotahome/redis-operator v1.1.1 test ==="
echo "Namespace: $NS"
echo ""

# 1. Delete RedisFailover CR
echo "[1] Deleting RedisFailover CR..."
kubectl delete redisfailover/redisfailover-ha -n "$NS" --timeout=60s 2>/dev/null || true

# 2. Delete external service
echo "[2] Deleting external service..."
kubectl delete -f "$(dirname "$0")/05-external.yaml" --timeout=30s 2>/dev/null || true

# 3. Delete operator
echo "[3] Deleting operator..."
kubectl delete -f "$(dirname "$0")/03-operator.yaml" --timeout=30s 2>/dev/null || true

# 4. Delete RBAC
echo "[4] Deleting RBAC..."
kubectl delete -f "$(dirname "$0")/02-rbac.yaml" --timeout=30s 2>/dev/null || true

# 5. Delete SA
echo "[5] Deleting ServiceAccount..."
kubectl delete -f "$(dirname "$0")/01-serviceaccount.yaml" --timeout=30s 2>/dev/null || true

# 6. Delete CRD
echo "[6] Deleting CRD..."
kubectl delete crd redisfailovers.databases.spotahome.com --timeout=30s 2>/dev/null || true

# 7. Delete namespace (cleanup everything)
echo "[7] Deleting namespace..."
kubectl delete ns "$NS" --timeout=60s 2>/dev/null || true

# 8. Scale up existing operator
echo "[8] Scaling up existing operator..."
kubectl scale deployment/redisoperator -n redis-spotahome --replicas=1 2>/dev/null || true

echo ""
echo "=== Done ==="