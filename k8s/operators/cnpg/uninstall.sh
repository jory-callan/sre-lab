#!/bin/bash
# uninstall.sh — CloudNativePG Operator 卸载
set -e

helm uninstall cnpg -n operators 2>/dev/null || true
kubectl delete crd -l app.kubernetes.io/name=cloudnative-pg 2>/dev/null || true

echo ""
echo "⚠️  注意：CRD 和实例 PVC 未删除，如需彻底清理："
echo "   kubectl delete crd -l app.kubernetes.io/name=cloudnative-pg"
echo "   kubectl delete pvc -n postgres --all"
echo ""
echo "✅ CloudNativePG operator 已卸载"
