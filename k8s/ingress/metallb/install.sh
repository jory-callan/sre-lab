#!/bin/bash

set -e

echo "=== 部署 MetalLB ==="

# 1. 安装 MetalLB 组件
echo "1. 安装 MetalLB 组件..."
kubectl apply -f manifests/remote-metallb-v0.14.8.yaml

# 2. 等待 Pod 就绪
echo "2. 等待 Pod 就绪..."
kubectl wait --for=condition=ready pod -n metallb-system -l app=metallb,component=controller --timeout=300s
kubectl wait --for=condition=ready pod -n metallb-system -l app=metallb,component=speaker --timeout=300s

# 3. 配置 IP 地址池
echo "3. 配置 IP 地址池..."
kubectl apply -f manifests/ipaddresspool.yaml

# 4. 配置 L2 宣告
echo "4. 配置 L2 宣告..."
kubectl apply -f manifests/l2advertisement.yaml

echo ""
echo "✅ MetalLB 部署完成！"
echo ""
echo "查看状态："
echo "  kubectl get pods -n metallb-system"
echo "  kubectl get ipaddresspools -n metallb-system"
