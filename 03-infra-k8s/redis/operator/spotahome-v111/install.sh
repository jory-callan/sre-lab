#!/usr/bin/env bash
set -euo pipefail

NS="${1:-redis-spotahome-v111}"
PASS="${2:-redis@czw}"

echo "=== Installing spotahome/redis-operator v1.1.1 + Redis 5.0.8 ==="
echo "Namespace: $NS"
echo "Password: $PASS"
echo ""

# 0. Scale down existing operator to avoid conflicts
echo "[0/6] Scaling down existing operator (if running)..."
kubectl scale deployment/redisoperator -n redis-spotahome --replicas=0 2>/dev/null || true

# 1. Create namespace
echo "[1/6] Creating namespace..."
kubectl apply -f "$(dirname "$0")/00-namespace.yaml"

# 2. Create auth secret
echo "[2/6] Creating auth secret..."
kubectl create secret generic redis-auth \
  -n "$NS" \
  --from-literal=password="$PASS" \
  --dry-run=client -o yaml | kubectl apply -f -

# 3. Deploy RBAC (prefixed names to avoid conflict)
echo "[3/6] Deploying RBAC..."
kubectl apply -f "$(dirname "$0")/02-rbac.yaml"

# 4. Deploy ServiceAccount
echo "[4/6] Deploying ServiceAccount..."
kubectl apply -f "$(dirname "$0")/01-serviceaccount.yaml"

# 5. Deploy operator
echo "[5/6] Deploying operator v1.1.1..."
kubectl apply -f "$(dirname "$0")/03-operator.yaml"
sleep 3

# 6. Create RedisFailover CR
echo "[6/6] Creating RedisFailover CR..."
kubectl apply -f "$(dirname "$0")/04-redisfailover-cr.yaml"

# 7. Create external service
echo "[7/7] Creating external service (NodePort 30207)..."
kubectl apply -f "$(dirname "$0")/05-external.yaml"

echo ""
echo "=== Waiting for pods... ==="
kubectl wait --for=condition=available -n "$NS" deployment/redisoperator-v111 --timeout=120s 2>/dev/null || true
echo ""
echo "=== Pod status ==="
kubectl get pods -n "$NS" -w