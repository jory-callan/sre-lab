#!/bin/bash
# verify.sh — 验证免密登录是否生效
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"

HOSTS=()
while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue

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

echo "▶ 验证免密登录..."
echo ""

FAIL=0
for host in "${HOSTS[@]}"; do
    result=$(ssh -o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=accept-new "root@${host}" "hostname" 2>&1) && {
        echo "  [✅] $host → $result"
    } || {
        echo "  [❌] $host → 连接失败"
        FAIL=1
    }
done

echo ""
if [[ "$FAIL" -eq 0 ]]; then
    echo "✅ 全部主机免密登录正常"
else
    echo "❌ 存在失败项，请检查"
fi