#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NAMESPACE="operators"
RELEASE_NAME="kubeblocks"

echo "=============================="
echo "KubeBlocks Operator 卸载"
echo "=============================="
echo ""

# ── 1. 删除所有 KubeBlocks 管理的集群资源 ──
echo "[1/4] 删除所有 KubeBlocks Cluster"
for ns in $(kubectl get clusters.apps.kubeblocks.io -A -o jsonpath='{.items[*].metadata.namespace}' 2>/dev/null); do
  kubectl delete clusters.apps.kubeblocks.io -n "$ns" --all --timeout=300s 2>/dev/null || true
done
echo "       完成"

# ── 2. 删除 KubeBlocks Helm release ──
echo ""
echo "[2/4] 删除 Helm release"
helm uninstall "$RELEASE_NAME" -n "$NAMESPACE" --timeout 5m --wait 2>/dev/null || true
echo "       完成"

# ── 3. 删除 KubeBlocks CRD（保留数据）──
echo ""
echo "[3/4] 删除 KubeBlocks CRD"
kubectl delete crd -l app.kubernetes.io/name=kubeblocks --timeout=60s 2>/dev/null || true
echo "       完成"

# ── 4. 清理残留 ──
echo ""
echo "[4/4] 清理残留资源"
kubectl delete mutatingwebhookconfiguration -l app.kubernetes.io/name=kubeblocks --timeout=30s 2>/dev/null || true
kubectl delete validatingwebhookconfiguration -l app.kubernetes.io/name=kubeblocks --timeout=30s 2>/dev/null || true
echo "       完成"

echo ""
echo "=============================="
echo "KubeBlocks 卸载完成"
echo "=============================="
echo ""
echo "提示: 若需同时删除数据，手动清理 PVC："
echo "  kubectl delete pvc -n mysql --all"
echo "  kubectl delete pvc -n redis --all"
