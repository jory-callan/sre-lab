#!/bin/bash
# uninstall.sh — 卸载 Gitea
# 用法: bash uninstall.sh
set -euo pipefail

NS="gitea"

echo "▶ 卸载 Gitea ..."

# 确认
read -p "确定卸载 Gitea 并清理 PVC？(y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "取消"
  exit 0
fi

helm uninstall gitea -n "$NS" 2>/dev/null || true
kubectl delete pvc -n "$NS" --all 2>/dev/null || true
kubectl delete namespace "$NS" --ignore-not-found

echo "✅ Gitea 已卸载"
echo "   PVC 已清理，数据不可恢复"
