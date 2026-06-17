#!/bin/bash

set -e

echo "=== 卸载 MetalLB ==="

# 1. 删除 IP 地址池
echo "1. 删除 IP 地址池..."
kubectl delete -f manifests/ipaddresspool.yaml 2>/dev/null || true

# 2. 删除 L2 宣告
echo "2. 删除 L2 宣告..."
kubectl delete -f manifests/l2advertisement.yaml 2>/dev/null || true

# 3. 删除 MetalLB 组件
echo "3. 删除 MetalLB 组件..."
kubectl delete -f manifests/remote-metallb-v0.14.8.yaml 2>/dev/null || true

echo ""
echo "✅ MetalLB 卸载完成！"
