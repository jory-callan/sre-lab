#!/bin/bash
# ETCD 维护工具箱
#
# 包含功能：
#   - 查看 etcd 状态
#   - 清理 etcd 空间（碎片整理）
#   - 备份 etcd
#   - 告警解除
#
# 使用方法：
#   sudo ./etcd-tool.sh status
#   sudo ./etcd-tool.sh compact
#   sudo ./etcd-tool.sh backup
#   sudo ./etcd-tool.sh defrag

set -e

# ==============================================
# 配置
# ==============================================

# ETCD 端点
ETCD_ENDPOINT="https://127.0.0.1:2379"

# ETCD 证书路径（k3s 默认位置）
ETCD_CA="/var/lib/rancher/k3s/server/tls/etcd/server-ca.crt"
ETCD_CERT="/var/lib/rancher/k3s/server/tls/etcd/server-client.crt"
ETCD_KEY="/var/lib/rancher/k3s/server/tls/etcd/server-client.key"

# 备份目录
BACKUP_DIR="/data/k3s/etcd-backups"

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
# 检查环境
# ==============================================
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        log_error "请使用 root 权限运行此脚本"
        exit 1
    fi
}

check_etcdctl() {
    if ! command -v etcdctl &> /dev/null; then
        log_error "etcdctl 未安装，正在安装..."
        install_etcdctl
    fi
}

install_etcdctl() {
    local ETCD_VERSION="v3.5.9"
    local ARCH="amd64"
    
    log_info "下载 etcdctl $ETCD_VERSION ..."
    
    curl -sL "https://gh-proxy.com/https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-${ARCH}.tar.gz" | \
        tar -zx -C /tmp --strip-components=1 "etcd-${ETCD_VERSION}-linux-${ARCH}/etcdctl"
    
    mv /tmp/etcdctl /usr/local/bin/
    chmod +x /usr/local/bin/etcdctl
    
    log_info "etcdctl 安装完成"
}

check_certs() {
    if [ ! -f "$ETCD_CERT" ]; then
        log_error "证书不存在: $ETCD_CERT"
        log_error "请确保 k3s server 已安装并运行"
        exit 1
    fi
}

# ==============================================
# etcdctl 包装
# ==============================================
etcdctl_cmd() {
    ETCDCTL_API=3 etcdctl \
        --endpoints="$ETCD_ENDPOINT" \
        --cacert="$ETCD_CA" \
        --cert="$ETCD_CERT" \
        --key="$ETCD_KEY" \
        "$@"
}

# ==============================================
# 功能函数
# ==============================================

# 查看状态
cmd_status() {
    log_info "ETCD 状态"
    log_info "============================================="
    
    echo ""
    log_info "端点状态:"
    etcdctl_cmd endpoint status --write-out=table
    
    echo ""
    log_info "端点健康:"
    etcdctl_cmd endpoint health
    
    echo ""
    log_info "告警列表:"
    etcdctl_cmd alarm list
}

# 压缩历史
cmd_compact() {
    log_info "获取当前版本..."
    local revision=$(etcdctl_cmd endpoint status --write-out=json | grep -o '"revision":[0-9]*' | grep -o '[0-9]*' | head -1)
    
    log_info "当前版本: $revision"
    
    if [ -z "$revision" ]; then
        log_error "无法获取版本"
        exit 1
    fi
    
    read -p "确认压缩到版本 $revision? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        log_info "取消"
        exit 0
    fi
    
    log_info "开始压缩..."
    etcdctl_cmd compact "$revision"
    
    log_info "压缩完成"
}

# 碎片整理
cmd_defrag() {
    log_info "碎片整理需要时间，不要中断！"
    read -p "确认碎片整理? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        log_info "取消"
        exit 0
    fi
    
    log_info "开始碎片整理..."
    etcdctl_cmd defrag --cluster
    
    log_info "碎片整理完成"
}

# 解除告警
cmd_alarm_disarm() {
    log_info "解除所有告警..."
    etcdctl_cmd alarm disarm
    
    log_info "告警已解除"
}

# 完整维护（压缩 + 碎片整理 + 解除告警）
cmd_maintenance() {
    log_info "开始完整维护流程..."
    
    cmd_compact
    echo ""
    cmd_defrag
    echo ""
    cmd_alarm_disarm
    echo ""
    cmd_status
    
    log_info "维护完成！"
}

# 备份
cmd_backup() {
    mkdir -p "$BACKUP_DIR"
    
    local TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    local BACKUP_FILE="$BACKUP_DIR/etcd-snapshot-${TIMESTAMP}.db"
    
    log_info "备份到 $BACKUP_FILE ..."
    
    etcdctl_cmd snapshot save "$BACKUP_FILE"
    
    local SIZE=$(du -h "$BACKUP_FILE" | awk '{print $1}')
    log_info "备份完成，大小: $SIZE"
    
    # 保留最近 10 个备份
    log_info "清理旧备份（保留最近 10 个）..."
    ls -t "$BACKUP_DIR"/etcd-snapshot-*.db | tail -n +11 | xargs -r rm -f
    
    log_info "当前备份列表:"
    ls -lh "$BACKUP_DIR"
}

# ==============================================
# 帮助信息
# ==============================================
show_help() {
    echo "ETCD 维护工具箱"
    echo ""
    echo "用法: $0 [命令]"
    echo ""
    echo "命令列表:"
    echo "  status       - 查看 etcd 状态"
    echo "  compact      - 压缩历史数据"
    echo "  defrag       - 碎片整理"
    echo "  alarm        - 解除告警"
    echo "  maintenance  - 完整维护流程（推荐）"
    echo "  backup       - 备份 etcd"
    echo "  help         - 显示帮助"
    echo ""
    echo "示例:"
    echo "  $0 status"
    echo "  $0 maintenance"
    echo "  $0 backup"
}

# ==============================================
# 主函数
# ==============================================
main() {
    local CMD="$1"
    
    check_root
    check_etcdctl
    check_certs
    
    case "$CMD" in
        status)
            cmd_status
            ;;
        compact)
            cmd_compact
            ;;
        defrag)
            cmd_defrag
            ;;
        alarm)
            cmd_alarm_disarm
            ;;
        maintenance)
            cmd_maintenance
            ;;
        backup)
            cmd_backup
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "未知命令: $CMD"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
