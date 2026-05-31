#!/bin/bash

set -e

echo "=== 部署 ingress-nginx ==="

# 1. 安装 ingress-nginx 组件
echo "1. 安装 ingress-nginx 组件..."
kubectl apply -f manifests/remote-ingress-nginx-v1.12.0.yaml

# 2. 等待 Pod 就绪
echo "2. 等待 Pod 就绪..."
kubectl wait --for=condition=ready pod -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --timeout=300s

# 3. 配置真实客户端 IP 透传
echo "3. 配置真实客户端 IP 透传..."
kubectl apply -f manifests/configmap-patch.yaml

echo ""
echo "✅ ingress-nginx 部署完成！"
echo ""
echo "查看状态："
echo "  kubectl get pods -n ingress-nginx"
echo "  kubectl get svc -n ingress-nginx"
