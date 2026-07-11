#!/bin/bash
# copy-ssh-key.sh — 复制 SSH 公钥到远程主机（免密登陆）
# 用法: bash copy-ssh-key.sh [-i <pub_key_file>] <user@host> [port]
#       bash copy-ssh-key.sh [-i <pub_key_file>] <user@start_ip-end_ip> [port]
# 示例: bash copy-ssh-key.sh root@192.168.1.100
#       bash copy-ssh-key.sh root@192.168.5.100-192.168.5.110
#       bash copy-ssh-key.sh admin@10.0.0.5 2222
#       bash copy-ssh-key.sh -i ~/.ssh/mykey.pub root@192.168.1.100
set -euo pipefail

# ── 解析选项 ──────────────────────────────────────────────────────
CUSTOM_KEY=""
while getopts ":i:h" opt; do
    case $opt in
        i) CUSTOM_KEY="$OPTARG" ;;
        h)
            echo "用法: bash copy-ssh-key.sh [-i <pub_key_file>] <user@host> [port]"
            echo "      bash copy-ssh-key.sh [-i <pub_key_file>] <user@start_ip-end_ip> [port]"
            echo ""
            echo "选项:"
            echo "  -i <pub_key_file>   指定要复制的 SSH 公钥文件（默认自动检测或生成）"
            echo ""
            echo "示例:"
            echo "  单机: bash copy-ssh-key.sh root@192.168.1.100"
            echo "  范围: bash copy-ssh-key.sh root@192.168.5.100-192.168.5.110"
            echo "  端口: bash copy-ssh-key.sh admin@10.0.0.5 2222"
            echo "  指定密钥: bash copy-ssh-key.sh -i ~/.ssh/mykey.pub root@192.168.1.100"
            exit 0
            ;;
        :) echo "❌ 选项 -$OPTARG 缺少参数" >&2; exit 1 ;;
        *) echo "❌ 未知选项: -$OPTARG" >&2; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

ARG="${1:-}"
SSH_PORT="${2:-22}"

[[ -z "$ARG" ]] && {
    echo "用法: bash copy-ssh-key.sh [-i <pub_key_file>] <user@host> [port]"
    echo "      bash copy-ssh-key.sh [-i <pub_key_file>] <user@start_ip-end_ip> [port]"
    echo "选项:"
    echo "  -i <pub_key_file>   指定要复制的 SSH 公钥文件（默认自动检测或生成）"
    echo "示例:"
    echo "  单机: bash copy-ssh-key.sh root@192.168.1.100"
    echo "  范围: bash copy-ssh-key.sh root@192.168.5.100-192.168.5.110"
    echo "  端口: bash copy-ssh-key.sh admin@10.0.0.5 2222"
    echo "  指定密钥: bash copy-ssh-key.sh -i ~/.ssh/mykey.pub root@192.168.1.100"
    exit 1
}

# ── 解析 user 与 IP 部分 ──────────────────────────────────────────
if [[ "$ARG" == *@* ]]; then
    SSH_USER="${ARG%%@*}"
    IP_PART="${ARG#*@}"
else
    SSH_USER=""
    IP_PART="$ARG"
fi

# ── 提取主机列表（单机或范围） ──────────────────────────────────────
HOSTS=()
if [[ "$IP_PART" == *-* ]]; then
    START_IP="${IP_PART%%-*}"
    END_IP="${IP_PART#*-}"

    # 校验两个 IP 的前三个八位组一致
    START_PREFIX="${START_IP%.*}"
    END_PREFIX="${END_IP%.*}"
    if [[ "$START_PREFIX" != "$END_PREFIX" ]]; then
        echo "❌ 范围的两个 IP 网段不一致: $START_PREFIX ≠ $END_PREFIX"
        exit 1
    fi

    START_LAST="${START_IP##*.}"
    END_LAST="${END_IP##*.}"
    for octet in $(seq "$START_LAST" "$END_LAST"); do
        HOSTS+=("${START_PREFIX}.${octet}")
    done
else
    HOSTS+=("$IP_PART")
fi

# ── 确定 SSH 公钥 ──────────────────────────────────────────────
PUB_KEY=""
if [[ -n "$CUSTOM_KEY" ]]; then
    if [[ ! -f "$CUSTOM_KEY" ]]; then
        echo "❌ 指定的公钥文件不存在: $CUSTOM_KEY" >&2
        exit 1
    fi
    PUB_KEY="$CUSTOM_KEY"
    echo "▶ 使用公钥（指定）: $PUB_KEY"
else
    # 自动检测已有密钥，无则生成
    if [[ ! -f "$HOME/.ssh/id_rsa.pub" && ! -f "$HOME/.ssh/id_ed25519.pub" ]]; then
        echo "▶ 未检测到 SSH 公钥，生成 ed25519 密钥..."
        ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -N ""
    fi

    for key in "$HOME/.ssh/id_ed25519.pub" "$HOME/.ssh/id_rsa.pub"; do
        [[ -f "$key" ]] && { PUB_KEY="$key"; break; }
    done
    echo "▶ 使用公钥: $(basename "$PUB_KEY")"
fi

# ── 逐个主机复制 ──────────────────────────────────────────────────
copy_key() {
    local host="$1"
    local target
    if [[ -n "$SSH_USER" ]]; then
        target="${SSH_USER}@${host}"
    else
        target="$host"
    fi

    echo ""
    echo "──────────────────────────────────────────"
    echo "→ $target"
    echo "──────────────────────────────────────────"

    if ssh-copy-id -p "$SSH_PORT" "$target" &>/dev/null; then
        echo "  ✅ 成功"
        return 0
    fi

    # ssh-copy-id 不可用时手动追加
    echo "  ⚠ ssh-copy-id 不可用，手动追加..."
    if cat "$PUB_KEY" | ssh -p "$SSH_PORT" -o StrictHostKeyChecking=no "$target" \
        "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"; then
        echo "  ✅ 成功"
    else
        echo "  ❌ 失败"
    fi
}

for host in "${HOSTS[@]}"; do
    copy_key "$host"
done

echo ""
echo "🎉 全部完成！共 ${#HOSTS[@]} 台主机。"
