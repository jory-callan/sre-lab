#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NAMESPACE="operators"
CHART_FILE="$SCRIPT_DIR/helm-chart-kubeblocks-1.0.2.tgz"
CRD_FILE="$SCRIPT_DIR/crd/kubeblocks_crds.yaml"
RELEASE_NAME="kubeblocks"

echo "=============================="
echo "KubeBlocks Operator 部署"
echo "=============================="

# ── 1. 创建命名空间 ──
echo ""
echo "[1/4] 创建命名空间"
kubectl create ns "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
echo "       完成"

# ── 2. 安装 KubeBlocks CRD ──
echo ""
echo "[2/4] 安装 KubeBlocks CRD（共 28 个）"
kubectl apply --server-side=true -f "$CRD_FILE"
echo "       完成"

# ── 3. 安装 KubeBlocks ──
echo ""
echo "[3/4] 安装 KubeBlocks v1.0.2"
helm upgrade --install "$RELEASE_NAME" "$CHART_FILE" \
  --namespace "$NAMESPACE" \
  --values "$SCRIPT_DIR/values.yaml" \
  --timeout 10m
echo "       完成"

# ── 4. 等待 operator 就绪 ──
echo ""
echo "[4/4] 等待 KubeBlocks operator 就绪"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kubeblocks \
  -n "$NAMESPACE" --timeout=300s 2>/dev/null || true

echo ""
echo "=============================="
echo "KubeBlocks 部署完成"
echo "=============================="
echo ""
echo "检查状态:"
echo "  kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=kubeblocks"
echo "  kubectl get addon -n $NAMESPACE"
echo "  kubectl get componentdefinition -A"
echo ""
echo "Addon 会自动安装（apecloud-mysql、redis），等待约 1-2 分钟"
echo "检查 addon 就绪:"
echo "  kubectl get addon -n $NAMESPACE -w"
echo ""
echo "下一步: 部署 MySQL / Redis 集群"
echo "  cd ../mysql/kubeblocks && bash install.sh"
echo "  cd ../redis/kubeblocks && bash install.sh"
