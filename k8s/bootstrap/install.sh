#!/bin/bash
# install.sh -- 一键安装集群基础设施组件
# 用法: bash install.sh [component ...]
#       不传参数则安装所有组件(按依赖顺序)
#       传参数则只安装指定组件
#
# 环境变量:
#   MIRROR_BASE  镜像加速地址 (默认: https://gh-proxy.com)
#                 设为空字符串则直连 GitHub
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

# 安装顺序(按依赖关系排列)
ORDERED_COMPONENTS=("cilium" "metallb" "ingress-nginx" "cert-manager" "nfs-storageclass" "longhorn")

if [ $# -gt 0 ]; then
    components=("$@")
else
    components=("${ORDERED_COMPONENTS[@]}")
fi

for comp in "${components[@]}"; do
    if [ -f "$comp/install.sh" ]; then
        echo ""
        echo "==============================================="
        echo ">> 安装 $comp ..."
        echo "==============================================="
        bash "$comp/install.sh"
        echo "[OK] $comp 完成"
    else
        echo "[ERR] 未知组件: $comp (未找到 $comp/install.sh)"
        exit 1
    fi
done

echo ""
echo "==============================================="
echo "[OK] 全部安装完成"
echo "==============================================="
echo ""
echo "组件清单:"
echo ""
if helm list -n kube-system 2>/dev/null | grep -q cilium; then
    echo "  [OK] Cilium       -- kubectl -n kube-system get pods -l k8s-app=cilium"
fi
if helm list -n metallb-system 2>/dev/null | grep -q metallb; then
    echo "  [OK] MetalLB      -- kubectl -n metallb-system get pods"
    echo "     配置: kubectl apply -f /root/bootstrap/metallb/metallb-ipaddresspool.yaml"
fi
if helm list -n ingress-nginx 2>/dev/null | grep -q ingress-nginx; then
    NIK_IP=$(kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    echo "  [OK] ingress-nginx -- kubectl -n ingress-nginx get pods"
    echo "     LB IP: ${NIK_IP:-等待分配中...}"
fi
if helm list -n nfs-storageclass 2>/dev/null | grep -q nfs-provisioner; then
    echo "  [OK] NFS Storage  -- kubectl get sc nfs-client"
fi
if helm list -n cert-manager 2>/dev/null | grep -q cert-manager; then
    echo "  [OK] cert-manager  -- kubectl -n cert-manager get pods"
fi
if helm list -n longhorn-system 2>/dev/null | grep -q longhorn; then
    echo "  [OK] Longhorn      -- kubectl -n longhorn-system get pods"
    echo "     UI: kubectl -n longhorn-system get svc longhorn-frontend"
fi
if helm list -n argocd 2>/dev/null | grep -q argocd; then
    echo "  [OK] ArgoCD       -- admin / \$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
fi
