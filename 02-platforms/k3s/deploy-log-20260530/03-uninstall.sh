#!/bin/bash
# K3s 集群卸载脚本
# 日期：2026-05-30

set -e

# --- 配置区域 ---
SERVER1="192.168.5.249"
SERVER2="192.168.5.101"
SERVER3="192.168.5.100"

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

# --- 警告 ---
log_warn "====================================="
log_warn "  警告！此操作将完全卸载 K3s 集群！"
log_warn "  所有数据将被删除！"
log_warn "====================================="
read -p "确认要继续吗？(yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    log_info "操作已取消"
    exit 0
fi

# --- 卸载 ---
log_info "开始卸载..."

for ip in $SERVER1 $SERVER2 $SERVER3; do
    log_info "卸载 $ip ..."
    ssh root@$ip '
        if command -v k3s-uninstall.sh &>/dev/null; then
            k3s-uninstall.sh
        fi
        rm -rf /var/lib/rancher/k3s
        rm -rf /etc/rancher/k3s
        rm -rf /run/k3s
        rm -rf /run/flannel
        rm -rf /var/lib/kubelet
        systemctl reset-failed k3s 2>/dev/null || true
    '
    log_info "$ip 卸载完成"
done

# --- 完成 ---
log_info "====================================="
log_info "  集群卸载完成！"
log_info "====================================="
