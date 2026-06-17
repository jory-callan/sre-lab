#!/usr/bin/env bash
set -euo pipefail

NS="${1:-redis-spotahome-v111}"
PASS="${2:-redis@czw}"

echo "=== Installing spotahome/redis-operator v1.1.1 + Redis 5.0.8 ==="
echo "Namespace: $NS"
echo "Password: $PASS"
echo ""

# 0. Scale down existing operator to avoid conflicts
echo "[0/7] Scaling down existing operator (if running)..."
kubectl scale deployment/redisoperator -n redis-spotahome --replicas=0 2>/dev/null || true

# 1. Create CRD first (operator v1.1.1 does NOT auto-register it)
echo "[1/7] Creating CRD (CustomResourceDefinition)..."
kubectl apply -f "$(dirname "$0")/00-crd.yaml"
echo "  Waiting for CRD to be established..."
kubectl wait --for=condition=established crd/redisfailovers.databases.spotahome.com --timeout=60s

# 2. Create namespace
echo "[2/7] Creating namespace..."
kubectl apply -f "$(dirname "$0")/00-namespace.yaml"

# 3. Create auth secret
echo "[3/7] Creating auth secret..."
kubectl create secret generic redis-auth \
  -n "$NS" \
  --from-literal=password="$PASS" \
  --dry-run=client -o yaml | kubectl apply -f -

# 4. Deploy RBAC (prefixed names to avoid conflict)
echo "[4/7] Deploying RBAC..."
kubectl apply -f "$(dirname "$0")/02-rbac.yaml"

# 5. Deploy ServiceAccount
echo "[5/7] Deploying ServiceAccount..."
kubectl apply -f "$(dirname "$0")/01-serviceaccount.yaml"

# 6. Deploy operator
echo "[6/7] Deploying operator v1.1.1..."
kubectl apply -f "$(dirname "$0")/03-operator.yaml"

# Wait for operator pod to be Ready (image pull takes time on quay.io)
echo "  Waiting for operator deployment to be ready..."
kubectl wait --for=condition=available -n "$NS" deployment/redisoperator-v111 --timeout=300s

# 7. Create RedisFailover CR
echo "[7/7] Creating RedisFailover CR..."
kubectl apply -f "$(dirname "$0")/04-redisfailover-cr.yaml"

# 8. Create external service
echo "[8/8] Creating external service (NodePort 30207)..."
kubectl apply -f "$(dirname "$0")/05-external.yaml"

echo ""
echo "=== Waiting for pods... ==="
kubectl wait --for=condition=available -n "$NS" deployment/redisoperator-v111 --timeout=120s 2>/dev/null || true
echo ""
echo "=== Pod status ==="
kubectl get pods -n "$NS" -w