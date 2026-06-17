#!/bin/bash
# k3s 完全卸载脚本
# 警告：此脚本会删除所有 k3s 相关的数据和配置

set -e

# ==============================================
# 颜色输出
# ==============================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ==============================================
# 检查是否为 root
# ==============================================
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        log_error "请使用 root 权限运行此脚本"
        exit 1
    fi
}

# ==============================================
# 确认卸载
# ==============================================
confirm_uninstall() {
    log_warn "============================================="
    log_warn "警告：此操作将完全卸载 k3s 并删除所有数据！"
    log_warn "这包括："
    log_warn "  - 所有 Pod/Deployment/Service"
    log_warn "  - etcd 数据"
    log_warn "  - 容器镜像"
    log_warn "  - 配置文件"
    log_warn "============================================="
    echo ""
    
    read -p "确认卸载吗？输入 'yes' 继续: " -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "取消卸载"
        exit 0
    fi
}

# ==============================================
# 停止 k3s 服务
# ==============================================
stop_services() {
    log_info "停止 k3s 服务..."
    
    systemctl stop k3s 2>/dev/null || true
    systemctl stop k3s-agent 2>/dev/null || true
    
    # 杀死残留进程
    pkill -f "k3s server" 2>/dev/null || true
    pkill -f "k3s agent" 2>/dev/null || true
    pkill -f "containerd" 2>/dev/null || true
    
    # 等待进程完全退出
    sleep 3
}

# ==============================================
# 运行 k3s 官方卸载脚本
# ==============================================
run_k3s_uninstall() {
    log_info "运行 k3s 官方卸载脚本..."
    
    if [ -f "/usr/local/bin/k3s-uninstall.sh" ]; then
        /usr/local/bin/k3s-uninstall.sh
    elif [ -f "/usr/bin/k3s-uninstall.sh" ]; then
        /usr/bin/k3s-uninstall.sh
    else
        log_warn "未找到 k3s-uninstall.sh，尝试手动清理"
    fi
    
    if [ -f "/usr/local/bin/k3s-agent-uninstall.sh" ]; then
        /usr/local/bin/k3s-agent-uninstall.sh
    elif [ -f "/usr/bin/k3s-agent-uninstall.sh" ]; then
        /usr/bin/k3s-agent-uninstall.sh
    fi
}

# ==============================================
# 手动清理残留文件
# ==============================================
cleanup_files() {
    log_info "清理残留文件..."
    
    # k3s 相关目录
    rm -rf /etc/rancher
    rm -rf /var/lib/rancher
    rm -rf /var/lib/kubelet
    rm -rf /etc/cni
    
    # k3s 二进制文件
    rm -f /usr/local/bin/k3s
    rm -f /usr/bin/k3s
    rm -f /usr/local/bin/kubectl
    rm -f /usr/bin/kubectl
    rm -f /usr/local/bin/crictl
    rm -f /usr/bin/crictl
    
    # systemd 服务文件
    rm -f /etc/systemd/system/k3s.service
    rm -f /etc/systemd/system/k3s-agent.service
    rm -rf /etc/systemd/system/k3s.service.d
    rm -f /etc/systemd/system/k3s.service.env
    
    # 网络配置
    rm -f /etc/NetworkManager/conf.d/k3s.conf
    rm -rf /var/lib/cni
    
    # 挂载清理
    for mount in $(mount | grep "k3s\|containerd" | awk '{print $3}'); do
        log_info "卸载挂载: $mount"
        umount "$mount" 2>/dev/null || true
    done
    
    # 网络接口清理
    for iface in $(ip link show 2>/dev/null | grep -E "flannel|cni|veth" | awk -F: '{print $2}' | tr -d ' '); do
        log_info "删除网络接口: $iface"
        ip link delete "$iface" 2>/dev/null || true
    done
}

# ==============================================
# 清理 kubectl 配置
# ==============================================
cleanup_kubectl() {
    log_info "清理 kubectl 配置..."
    
    if [ -f "$HOME/.kube/config" ]; then
        if [ -L "$HOME/.kube/config" ]; then
            # 如果是符号链接
            LINK_TARGET=$(readlink "$HOME/.kube/config" 2>/dev/null || true)
            if [[ "$LINK_TARGET" == *"/etc/rancher/k3s/k3s.yaml"* ]]; then
                rm -f "$HOME/.kube/config"
                log_info "已删除 $HOME/.kube/config 符号链接"
            fi
        else
            # 检查文件内容是否来自 k3s
            if grep -q "k3s" "$HOME/.kube/config" 2>/dev/null; then
                read -p "是否删除 $HOME/.kube/config？[y/N] " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    rm -f "$HOME/.kube/config"
                    log_info "已删除 $HOME/.kube/config"
                fi
            fi
        fi
    fi
    
    rmdir "$HOME/.kube" 2>/dev/null || true
}

# ==============================================
# 重载 systemd
# ==============================================
reload_systemd() {
    log_info "重载 systemd 配置..."
    systemctl daemon-reload
    systemctl reset-failed 2>/dev/null || true
}

# ==============================================
# 显示完成信息
# ==============================================
show_completion() {
    log_info "============================================="
    log_info "k3s 卸载完成！"
    log_info "============================================="
    echo ""
    log_warn "建议重启系统以确保完全清理"
}

# ==============================================
# 主函数
# ==============================================
main() {
    log_info "开始卸载 k3s..."
    
    check_root
    confirm_uninstall
    stop_services
    run_k3s_uninstall
    cleanup_files
    cleanup_kubectl
    reload_systemd
    show_completion
    
    log_info "卸载成功！"
}

# 运行主函数
main "$@"
