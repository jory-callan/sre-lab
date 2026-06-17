#!/bin/bash
# 数据盘准备脚本
#
# 使用场景：
#   - 系统盘只有 40G，不够存放 etcd、容器镜像、日志
#   - 需要挂载独立 SSD 盘到 /data 目录
#
# 使用方法：
#   1. 查看磁盘: lsblk
#   2. 编辑此脚本，修改 DISK_DEVICE
#   3. 运行: sudo ./prepare-data-disk.sh

set -e

# ==============================================
# 配置（请根据实际情况修改）
# ==============================================

# 磁盘设备（查看: lsblk）
# 例如: /dev/sdb, /dev/nvme0n1, /dev/vdb
DISK_DEVICE=""

# 挂载点
DATA_MOUNT="/data"

# 文件系统类型
FS_TYPE="xfs"

# 是否自动备份原有数据（如果挂载点已存在）
BACKUP_EXISTING=true

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

check_disk_config() {
    if [ -z "$DISK_DEVICE" ]; then
        log_error "请先编辑此脚本，配置 DISK_DEVICE"
        echo ""
        echo "可用磁盘设备："
        lsblk -d -o NAME,SIZE,TYPE,MOUNTPOINT
        echo ""
        echo "示例：DISK_DEVICE=\"/dev/sdb\""
        exit 1
    fi
}

check_disk_exist() {
    if [ ! -b "$DISK_DEVICE" ]; then
        log_error "磁盘设备不存在: $DISK_DEVICE"
        echo ""
        echo "可用磁盘设备："
        lsblk -d -o NAME,SIZE,TYPE,MOUNTPOINT
        exit 1
    fi
}

check_disk_mounted() {
    if lsblk -no MOUNTPOINT "$DISK_DEVICE" | grep -q .; then
        log_error "磁盘已挂载，请先卸载:"
        lsblk -o NAME,SIZE,MOUNTPOINT "$DISK_DEVICE"
        exit 1
    fi
}

# ==============================================
# 备份现有数据
# ==============================================
backup_existing_data() {
    if [ -d "$DATA_MOUNT" ] && [ "$(ls -A $DATA_MOUNT 2>/dev/null)" ]; then
        if [ "$BACKUP_EXISTING" = "true" ]; then
            local BACKUP_DIR="${DATA_MOUNT}.backup.$(date +%Y%m%d%H%M%S)"
            log_warn "目录 $DATA_MOUNT 已存在且非空"
            log_info "备份到 $BACKUP_DIR ..."
            mv "$DATA_MOUNT" "$BACKUP_DIR"
            log_info "备份完成"
        else
            log_error "目录 $DATA_MOUNT 已存在且非空，请手动处理"
            exit 1
        fi
    fi
}

# ==============================================
# 分区和格式化
# ==============================================
format_disk() {
    log_info "开始格式化磁盘 $DISK_DEVICE (类型: $FS_TYPE)..."
    log_warn "警告：这将清除磁盘上的所有数据！"
    read -p "确认格式化? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log_info "取消操作"
        exit 0
    fi
    
    # 擦除分区表
    log_info "擦除分区表..."
    wipefs -a "$DISK_DEVICE"
    
    # 创建分区（整个磁盘一个分区）
    log_info "创建分区..."
    parted -s "$DISK_DEVICE" mklabel gpt
    parted -s "$DISK_DEVICE" mkpart primary 0% 100%
    
    # 等待设备就绪
    sleep 2
    
    # 格式化分区
    local PARTITION="${DISK_DEVICE}1"
    if [ ! -b "$PARTITION" ]; then
        PARTITION="${DISK_DEVICE}p1"  # nvme 设备格式
    fi
    
    log_info "格式化分区 $PARTITION 为 $FS_TYPE ..."
    if [ "$FS_TYPE" = "xfs" ]; then
        mkfs.xfs -f -L K3SDATA "$PARTITION"
    else
        mkfs.ext4 -F -L K3SDATA "$PARTITION"
    fi
    
    log_info "格式化完成"
}

# ==============================================
# 挂载
# ==============================================
mount_disk() {
    # 创建挂载点
    mkdir -p "$DATA_MOUNT"
    
    # 确定分区设备
    local PARTITION="${DISK_DEVICE}1"
    if [ ! -b "$PARTITION" ]; then
        PARTITION="${DISK_DEVICE}p1"
    fi
    
    # 获取 UUID
    local UUID=$(blkid -s UUID -o value "$PARTITION")
    
    if [ -z "$UUID" ]; then
        log_error "无法获取分区 UUID"
        exit 1
    fi
    
    log_info "分区 UUID: $UUID"
    
    # 临时挂载
    log_info "临时挂载..."
    mount "$PARTITION" "$DATA_MOUNT"
    
    # 创建 k3s 目录结构
    log_info "创建目录结构..."
    mkdir -p "$DATA_MOUNT/k3s"
    mkdir -p "$DATA_MOUNT/k3s/snapshots"
    mkdir -p "$DATA_MOUNT/k3s/audit"
    mkdir -p "$DATA_MOUNT/containerd"
    mkdir -p "$DATA_MOUNT/kubelet"
    
    chmod 700 "$DATA_MOUNT/k3s"
    
    # 添加到 fstab
    log_info "添加到 /etc/fstab ..."
    local FSTAB_LINE="UUID=$UUID $DATA_MOUNT $FS_TYPE defaults,noatime 0 0"
    
    if grep -q "$DATA_MOUNT" /etc/fstab; then
        log_warn "fstab 中已存在 $DATA_MOUNT，跳过添加"
    else
        echo "$FSTAB_LINE" >> /etc/fstab
        log_info "已添加到 fstab"
    fi
    
    # 验证 fstab
    log_info "验证 fstab..."
    umount "$DATA_MOUNT"
    mount "$DATA_MOUNT"
    
    log_info "挂载成功"
}

# ==============================================
# 显示完成信息
# ==============================================
show_completion() {
    log_info "============================================="
    log_info "数据盘准备完成！"
    log_info "============================================="
    echo ""
    log_info "挂载点: $DATA_MOUNT"
    log_info "磁盘设备: $DISK_DEVICE"
    echo ""
    log_info "k3s 目录结构:"
    log_info "  $DATA_MOUNT/k3s/"
    log_info "  $DATA_MOUNT/k3s/snapshots/"
    log_info "  $DATA_MOUNT/k3s/audit/"
    echo ""
    log_info "下一步："
    log_info "  1. 编辑 config.yaml，设置 data-dir: \"$DATA_MOUNT/k3s\""
    log_info "  2. 运行 ./install-k3s.sh 安装 k3s"
    echo ""
    df -h "$DATA_MOUNT"
}

# ==============================================
# 主函数
# ==============================================
main() {
    log_info "开始准备数据盘..."
    
    check_root
    check_disk_config
    check_disk_exist
    check_disk_mounted
    backup_existing_data
    format_disk
    mount_disk
    show_completion
    
    log_info "完成！"
}

# 运行主函数
main "$@"
