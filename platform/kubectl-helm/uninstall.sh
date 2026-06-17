#!/bin/bash
set -e

# Kubectl + Helm 卸载脚本

echo "==> 删除 kubectl"
rm -f /usr/local/bin/kubectl

echo "==> 删除 helm"
rm -f /usr/local/bin/helm

echo ""
echo "卸载完成。"