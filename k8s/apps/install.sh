#!/bin/bash
# install.sh — 自托管应用一键安装
# 用法: bash install.sh [component ...]
#       不传参数则安装所有应用
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

if [ $# -gt 0 ]; then
    components=("$@")
else
    components=("gitea" "argocd" "kite")
fi

for comp in "${components[@]}"; do
    if [ -f "$comp/install.sh" ]; then
        echo ""
        echo "═══════════════════════════════════════════════"
        echo "▶ 安装 $comp ..."
        echo "═══════════════════════════════════════════════"
        bash "$comp/install.sh"
        echo "✅ $comp 完成"
    else
        echo "❌ 未知应用: $comp (未找到 $comp/install.sh)"
        exit 1
    fi
done

echo ""
echo "═══════════════════════════════════════════════"
echo "✅ 全部安装完成"
echo "═══════════════════════════════════════════════"
