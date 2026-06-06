#!/bin/bash
set -e

# Hermes Agent 卸载脚本
# 移除 Hermes Agent 及所有相关组件（保留 uv 和清华源配置）。

echo "==> 删除软链"
rm -f /usr/local/bin/hermes
rm -f /usr/local/bin/hermes-acp
rm -f /usr/local/bin/hermes-agent

echo "==> 删除源码和 venv"
rm -rf /usr/local/lib/hermes-agent

echo "==> 删除 hermes 数据目录"
rm -rf /root/.hermes

echo "==> 删除 uv 安装的 Python 3.11"
rm -rf /usr/local/share/uv/python/cpython-3.11.15-linux-x86_64-gnu

echo ""
echo "卸载完成。"
echo "保留项：uv（/root/.local/bin/uv）、清华源配置（/root/.config/uv/uv.toml）"
echo "如需删除 uv：rm -rf /root/.local/bin/uv /root/.local/bin/uvx /root/.config/uv"
