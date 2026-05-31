#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== K3s 高频组件快速安装 ==="
echo ""
echo "选择要安装的组件："
echo "1) ingress-nginx"
echo "2) MetalLB"
echo "3) demo-go-tiny"
echo "4) 安装所有"
echo "q) 退出"
echo ""
read -p "请输入选项: " choice

case $choice in
  1)
    echo ""
    echo "安装 ingress-nginx..."
    cd "$SCRIPT_DIR/../03-infra-k8s/ingress-nginx/dev"
    ./install.sh
    ;;
  2)
    echo ""
    echo "安装 MetalLB..."
    cd "$SCRIPT_DIR/../03-infra-k8s/metallb/dev"
    ./install.sh
    ;;
  3)
    echo ""
    echo "安装 demo-go-tiny..."
    cd "$SCRIPT_DIR/../04-apps-k8s/demo-go-tiny/dev"
    ./install.sh
    ;;
  4)
    echo ""
    echo "安装所有组件..."
    cd "$SCRIPT_DIR/../03-infra-k8s/ingress-nginx/dev"
    ./install.sh
    cd "$SCRIPT_DIR/../03-infra-k8s/metallb/dev"
    ./install.sh
    cd "$SCRIPT_DIR/../04-apps-k8s/demo-go-tiny/dev"
    ./install.sh
    ;;
  q)
    echo "退出"
    exit 0
    ;;
  *)
    echo "无效选项"
    exit 1
    ;;
esac

echo ""
echo "✅ 完成！"
