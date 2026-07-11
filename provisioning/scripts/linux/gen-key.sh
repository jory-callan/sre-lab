#!/bin/bash
# gen-key.sh — 生成 SSH 密钥对 (若不存在)
set -euo pipefail

KEY="${HOME}/.ssh/id_ed25519"

if [[ -f "$KEY" ]]; then
    echo "✅ 密钥已存在: $KEY"
else
    echo "▶ 生成密钥: $KEY"
    ssh-keygen -t ed25519 -f "$KEY" -N "" -C "$(whoami)@$(hostname)-$(date +%Y%m%d)"
    echo "✅ 密钥生成完成"
fi

echo ""
echo "公钥内容:"
cat "${KEY}.pub"