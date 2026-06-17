#!/bin/bash

set -e

echo "=== 卸载 demo-go-tiny ==="

# 1. 删除 Ingress
echo "1. 删除 Ingress..."
kubectl delete -f manifests/ingress.yaml 2>/dev/null || true

# 2. 删除 Service
echo "2. 删除 Service..."
kubectl delete -f manifests/service.yaml 2>/dev/null || true

# 3. 删除 Deployment
echo "3. 删除 Deployment..."
kubectl delete -f manifests/deployment.yaml 2>/dev/null || true

echo ""
echo "✅ demo-go-tiny 卸载完成！"
