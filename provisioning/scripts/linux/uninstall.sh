#!/bin/bash
set -e

# Node.js 环境卸载脚本
# 移除 fnm、Node.js、npm 及所有配置。

echo "==> 删除 fnm"
rm -f /usr/local/bin/fnm

echo "==> 删除 fnm 环境变量"
rm -f /etc/profile.d/fnm.sh

echo "==> 删除 Node.js 软链"
rm -f /usr/local/bin/node
rm -f /usr/local/bin/npm
rm -f /usr/local/bin/npx
rm -f /usr/local/bin/corepack

echo "==> 删除 fnm 安装数据"
rm -rf /root/.local/share/fnm

echo "==> 删除 npm 配置"
rm -f /etc/npmrc
rm -f /root/.npmrc

echo "==> 恢复 .bashrc"
rm -f /root/.bashrc.bak

echo ""
echo "卸载完成。"
