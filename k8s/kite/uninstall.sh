#!/bin/bash
# uninstall.sh — Kite 卸载
set -e

helm uninstall kite -n kite 2>/dev/null || true
kubectl delete namespace kite 2>/dev/null || true

echo ""
echo "⚠️  PVC 已保留，如需彻底删除："
echo "   kubectl delete pvc -n kite -l app.kubernetes.io/name=kite"
echo ""
echo "✅ Kite 卸载完成"
