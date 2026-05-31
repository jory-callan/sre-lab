#!/bin/bash

set -e

echo "=== 卸载 ingress-nginx ==="

# 1. 删除 ConfigMap（可选，remote 资源删除时会一并删除）
echo "1. 删除 ConfigMap..."
kubectl delete -f manifests/configmap-patch.yaml 2>/dev/null || true

# 2. 删除 ingress-nginx 组件
echo "2. 删除 ingress-nginx 组件..."
kubectl delete -f manifests/remote-ingress-nginx-v1.12.0.yaml 2>/dev/null || true

echo ""
echo "✅ ingress-nginx 卸载完成！"
