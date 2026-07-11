#!/bin/bash
# 批量免密登录脚本（Ed25519 密钥对）

SSH_USER="root"
SSH_PORT=22
TIMEOUT=5
KEY_FILE="$HOME/.ssh/id_ed25519"
PUB_KEY="${KEY_FILE}.pub"
PASSWORD="your_secure_passwd"

# 生成 Ed25519 密钥对（如果还没有）
[ ! -f "$KEY_FILE" ] && ssh-keygen -t ed25519 -b 256 -N "" -f "$KEY_FILE"

# 遍历 IP 范围
for i in $(seq 110 111); do
    IP="192.168.5.$i"

    # 连通性检测，超时跳过
    ping -c 1 -W $TIMEOUT $IP &>/dev/null || { echo "跳过 $IP (无响应)"; continue; }

    # 复制公钥，指定密钥文件和端口
    sshpass -p "$PASSWORD" ssh-copy-id -i "$PUB_KEY" -o StrictHostKeyChecking=no -p $SSH_PORT $SSH_USER@$IP &>/dev/null

    if [ $? -eq 0 ]; then
        echo "✅ $IP 免密配置成功"
    else
        echo "❌ $IP 配置失败"
    fi
done