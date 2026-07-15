#!/bin/bash
# uninstall.sh — 卸载 DolphinScheduler + SeaTunnel Engine
# 用法: bash uninstall.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NS="dolphinscheduler"

echo ">> 卸载 SeaTunnel Engine ..."
helm uninstall st -n "${NS}" 2>/dev/null || true

echo ">> 卸载 DolphinScheduler ..."
helm uninstall ds -n "${NS}" 2>/dev/null || true

echo ">> 删除 ZooKeeper ..."
kubectl delete -f "${SCRIPT_DIR}/zookeeper/zookeeper.yaml" 2>/dev/null || true

echo ">> 删除 PVC ..."
kubectl delete pvc -n "${NS}" -l app.kubernetes.io/instance=ds 2>/dev/null || true
kubectl delete pvc -n "${NS}" -l app.kubernetes.io/instance=st 2>/dev/null || true
kubectl delete pvc -n "${NS}" -l app=ds-zookeeper 2>/dev/null || true

echo ">> 删除命名空间 ..."
kubectl delete namespace "${NS}" 2>/dev/null || true

echo ""
echo "✅ 卸载完成"
