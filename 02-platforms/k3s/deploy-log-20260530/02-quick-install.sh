#!/bin/bash
# K3s 三节点 HA 集群快速安装脚本
# 日期：2026-05-30

set -e

# --- 配置区域 ---
SERVER1="192.168.5.249"
SERVER2="192.168.5.101"
SERVER3="192.168.5.100"
K3S_VERSION="v1.31.5-k3s1"
TOKEN="k3s-ha-40yhw4NU19XyWZC5naohc5tSoPMC6wKx3nB34zXo624"
CONFIG_DIR="/etc/rancher/k3s"
INSTALL_SCRIPT="https://rancher-mirror.rancher.cn/k3s/k3s-install.sh"

# --- 颜色 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- 函数 ---
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# --- 步骤 1: 检查环境 ---
log_info "步骤 1: 检查环境"
for ip in $SERVER1 $SERVER2 $SERVER3; do
    echo -n "检查 $ip ... "
    if ssh root@$ip 'hostname >/dev/null 2>&1'; then
        echo -e "${GREEN}OK${NC}"
    else
        log_error "无法连接到 $ip"
        exit 1
    fi
done

# --- 步骤 2: 设置主机名 ---
log_info "步骤 2: 设置主机名"
ssh root@$SERVER1 'hostnamectl set-hostname k3s-server-1'
ssh root@$SERVER2 'hostnamectl set-hostname k3s-server-2'
ssh root@$SERVER3 'hostnamectl set-hostname k3s-server-3'
log_info "主机名设置完成"

# --- 步骤 3: 分发配置文件 ---
log_info "步骤 3: 分发配置文件"
for ip in $SERVER1 $SERVER2 $SERVER3; do
    ssh root@$ip "mkdir -p $CONFIG_DIR"
    scp config.yaml registries.yaml root@$ip:$CONFIG_DIR/
    log_info "配置文件已分发到 $ip"
done

# --- 步骤 4: 安装第一个节点 ---
log_info "步骤 4: 安装第一个节点 ($SERVER1)"
ssh root@$SERVER1 "
    curl -sfL $INSTALL_SCRIPT | \
    INSTALL_K3S_VERSION=$K3S_VERSION INSTALL_K3S_MIRROR=cn \
    sh -s - server --cluster-init --config $CONFIG_DIR/config.yaml
"

# 等待节点 Ready
log_info "等待节点 Ready ..."
sleep 30

# 验证
ssh root@$SERVER1 'k3s kubectl get nodes'

# --- 步骤 5: 获取 Token ---
log_info "步骤 5: 获取 Token"
TOKEN=$(ssh root@$SERVER1 "cat /var/lib/rancher/k3s/server/token")
log_info "Token: $TOKEN"

# --- 步骤 6: 加入第二个节点 ---
log_info "步骤 6: 加入第二个节点 ($SERVER2)"
ssh root@$SERVER2 "
    curl -sfL $INSTALL_SCRIPT | \
    INSTALL_K3S_VERSION=$K3S_VERSION INSTALL_K3S_MIRROR=cn \
    sh -s - server --server https://$SERVER1:6443 --token $TOKEN --config $CONFIG_DIR/config.yaml
"

# --- 步骤 7: 加入第三个节点 ---
log_info "步骤 7: 加入第三个节点 ($SERVER3)"
ssh root@$SERVER3 "
    curl -sfL $INSTALL_SCRIPT | \
    INSTALL_K3S_VERSION=$K3S_VERSION INSTALL_K3S_MIRROR=cn \
    sh -s - server --server https://$SERVER1:6443 --token $TOKEN --config $CONFIG_DIR/config.yaml
"

# 等待所有节点 Ready
log_info "等待所有节点 Ready ..."
sleep 60

# --- 步骤 8: 验证集群 ---
log_info "步骤 8: 验证集群"
ssh root@$SERVER1 'k3s kubectl get nodes -o wide'

# --- 步骤 9: 安装 ingress-nginx ---
log_info "步骤 9: 安装 ingress-nginx"
ssh root@$SERVER1 '
    k3s kubectl apply -f https://gh-proxy.com/https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.0/deploy/static/provider/cloud/deploy.yaml
'

# --- 完成 ---
log_info "====================================="
log_info "  集群安装完成！"
log_info "====================================="
log_info ""
log_info "访问集群:"
log_info "  在任意节点上执行: k3s kubectl ..."
log_info ""
log_info "获取 kubeconfig:"
log_info "  ssh root@$SERVER1 'cat /etc/rancher/k3s/k3s.yaml'"
log_info ""
log_info "查看节点状态:"
log_info "  ssh root@$SERVER1 'k3s kubectl get nodes -o wide'"
log_info ""
