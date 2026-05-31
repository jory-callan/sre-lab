#!/bin/bash
# k3s 安装脚本（简化版）
# 配置文件：
#   - install-config.yaml - 安装过程配置
#   - config.yaml - k3s 主配置
#   - registries.yaml - 镜像源配置

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
# 配置（编辑这里来配置）
# ==============================================

# --- 基本配置 ---
K3S_VERSION="v1.29.1+k3s1"
NODE_ROLE="server"  # server 或 agent

# --- 加入集群配置（如果是第一个节点，不需要修改）
K3S_URL=""
# K3S_TOKEN=""

# --- 安装源配置 ---
INSTALL_K3S_MIRROR="cn"
INSTALL_K3S_SKIP_SELINUX_RPM="true"

# --- 安装后配置 ---
SETUP_KUBECTL="true"
INSTALL_HELM="true"

# ==============================================
# 检查环境
# ==============================================
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        log_error "请使用 root 权限运行此脚本"
        exit 1
    fi
}

# ==============================================
# 部署配置文件
# ==============================================
deploy_config_files() {
    local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    log_info "部署配置文件..."
    
    mkdir -p /etc/rancher/k3s
    
    # 部署 k3s 主配置
    if [ -f "$SCRIPT_DIR/config.yaml" ]; then
        cp "$SCRIPT_DIR/config.yaml" /etc/rancher/k3s/config.yaml
        log_info "  - config.yaml -> /etc/rancher/k3s/config.yaml"
    fi
    
    # 部署镜像源配置
    if [ -f "$SCRIPT_DIR/registries.yaml" ]; then
        cp "$SCRIPT_DIR/registries.yaml" /etc/rancher/k3s/registries.yaml
        log_info "  - registries.yaml -> /etc/rancher/k3s/registries.yaml"
    fi
    
    # 部署 kubelet 配置（如果存在）
    if [ -f "$SCRIPT_DIR/kubelet.config.yaml" ]; then
        cp "$SCRIPT_DIR/kubelet.config.yaml" /etc/rancher/k3s/kubelet.config.yaml
        log_info "  - kubelet.config.yaml -> /etc/rancher/k3s/kubelet.config.yaml"
    fi
}

# ==============================================
# 安装 k3s
# ==============================================
install_k3s() {
    log_info "安装 k3s $NODE_ROLE (版本: $K3S_VERSION)..."
    
    # 构建环境变量
    local INSTALL_OPTS=""
    INSTALL_OPTS="$INSTALL_OPTS INSTALL_K3S_MIRROR=$INSTALL_K3S_MIRROR"
    INSTALL_OPTS="$INSTALL_OPTS INSTALL_K3S_VERSION=$K3S_VERSION"
    INSTALL_OPTS="$INSTALL_OPTS INSTALL_K3S_SKIP_SELINUX_RPM=$INSTALL_K3S_SKIP_SELINUX_RPM"
    
    if [ -n "$K3S_URL" ]; then
        INSTALL_OPTS="$INSTALL_OPTS K3S_URL=$K3S_URL"
    fi
    
    if [ -n "$K3S_TOKEN" ]; then
        INSTALL_OPTS="$INSTALL_OPTS K3S_TOKEN=$K3S_TOKEN"
    fi
    
    # 执行安装
    curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | \
        env $INSTALL_OPTS \
        sh -s - "$NODE_ROLE"
}

# ==============================================
# 配置 kubectl
# ==============================================
setup_kubectl() {
    if [ "$SETUP_KUBECTL" != "true" ]; then
        return
    fi
    
    if [ "$NODE_ROLE" != "server" ]; then
        return
    fi
    
    log_info "配置 kubectl..."
    
    mkdir -p "$HOME/.kube"
    cp /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
    chown "$(id -u):$(id -g)" "$HOME/.kube/config"
    
    log_info "kubectl 配置完成"
}

# ==============================================
# 安装 helm
# ==============================================
install_helm() {
    if [ "$INSTALL_HELM" != "true" ]; then
        return
    fi
    
    if command -v helm &> /dev/null; then
        log_warn "helm 已安装，跳过"
        return
    fi
    
    log_info "安装 helm..."
    
    curl -fsSL -o /tmp/get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 /tmp/get_helm.sh
    /tmp/get_helm.sh
    rm -f /tmp/get_helm.sh
    
    # 配置国内源
    helm repo add stable "https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts" 2>/dev/null || true
    helm repo add azure "http://mirror.azure.cn/kubernetes/charts" 2>/dev/null || true
    helm repo update 2>/dev/null || true
    
    log_info "helm 安装完成"
}

# ==============================================
# 显示 token
# ==============================================
show_token() {
    if [ "$NODE_ROLE" != "server" ]; then
        return
    fi
    
    if [ ! -f /var/lib/rancher/k3s/server/token ]; then
        return
    fi
    
    log_info "节点加入 token:"
    cat /var/lib/rancher/k3s/server/token
    echo ""
}

# ==============================================
# 显示完成信息
# ==============================================
show_completion() {
    log_info "============================================="
    log_info "k3s 安装完成！"
    log_info "============================================="
    echo ""
    
    log_info "配置文件位置："
    log_info "  /etc/rancher/k3s/config.yaml"
    log_info "  /etc/rancher/k3s/registries.yaml"
    echo ""
    
    if [ "$NODE_ROLE" = "server" ]; then
        log_info "常用命令："
        log_info "  kubectl get nodes          - 查看节点"
        log_info "  kubectl get pods -A        - 查看所有 Pod"
        log_info "  k3s etcd-snapshot list     - 查看 etcd 快照"
        log_info "  systemctl status k3s       - 查看 k3s 状态"
        log_info "  systemctl restart k3s      - 重启 k3s"
        log_info "  cat /etc/rancher/k3s/config.yaml - 查看配置"
    else
        log_info "常用命令："
        log_info "  systemctl status k3s-agent"
    fi
}

# ==============================================
# 主函数
# ==============================================
main() {
    log_info "开始安装 k3s (角色: $NODE_ROLE)..."
    
    check_root
    deploy_config_files
    install_k3s
    setup_kubectl
    install_helm
    show_token
    show_completion
    
    log_info "安装成功！"
}

# 运行主函数
main "$@"
