#!/bin/bash
# copy.sh — 复制 SSH 公钥到 hosts.txt 中的所有主机
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ ! -f "${HOME}/.ssh/id_ed25519.pub" ]]; then
    echo "❌ 公钥不存在，先执行: bash gen-key.sh"
    exit 1
fi

echo "▶ 读取主机列表..."
HOSTS=()
while IFS= read -r line; do
    # 跳过空行和注释
    [[ -z "$line" || "$line" == \#* ]] && continue

    # 解析范围: 192.168.5.100-110
    if [[ "$line" =~ ^([0-9]+\.[0-9]+\.[0-9]+\.)([0-9]+)-([0-9]+)$ ]]; then
        prefix="${BASH_REMATCH[1]}"
        start="${BASH_REMATCH[2]}"
        end="${BASH_REMATCH[3]}"
        for i in $(seq "$start" "$end"); do
            HOSTS+=("${prefix}${i}")
        done
    else
        HOSTS+=("$line")
    fi
done < "$DIR/hosts.txt"

echo "→ 共 ${#HOSTS[@]} 台主机"
echo ""

for host in "${HOSTS[@]}"; do
    echo "▶ $host"
    ssh-copy-id -i "${HOME}/.ssh/id_ed25519.pub" -o StrictHostKeyChecking=accept-new "root@${host}" 2>&1 | sed 's/^/  /'
done

echo ""
echo "✅ 全部完成"