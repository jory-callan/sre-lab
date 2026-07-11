#!/bin/bash

set -e

echo "=== 部署 demo-go-tiny ==="

# 1. 部署 Deployment
echo "1. 部署 Deployment..."
kubectl apply -f manifests/deployment.yaml

# 2. 部署 Service
echo "2. 部署 Service..."
kubectl apply -f manifests/service.yaml

# 3. 部署 Ingress
echo "3. 部署 Ingress..."
kubectl apply -f manifests/ingress.yaml

echo ""
echo "✅ demo-go-tiny 部署完成！"
echo ""
echo "查看状态："
echo "  kubectl get pods -l app=demo-go-tiny"
echo "  kubectl get svc demo-go-tiny"
echo "  kubectl get ingress demo-go-tiny"
