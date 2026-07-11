#!/bin/bash
# uninstall.sh — 卸载 kdebug
# 用法: bash uninstall.sh
set -euo pipefail

NS="kdebug"

echo ">> 卸载 kdebug ..."

read -p "确定卸载 kdebug 并清理命名空间？(y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "取消"
  exit 0
fi

helm uninstall kdebug -n "$NS" 2>/dev/null || true
kubectl delete namespace "$NS" --ignore-not-found

echo "✅ kdebug 已卸载"
