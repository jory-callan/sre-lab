#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NAMESPACE="operators"
CHART_NAME="kubeblocks"
CHART_VERSION="1.0.0"
RELEASE_NAME="kubeblocks"

echo "=============================="
echo "KubeBlocks Operator 部署"
echo "=============================="

# ── 1. 添加 Helm 仓库 ──
echo ""
echo "[1/5] 添加 Helm 仓库"
helm repo add helm-hosted http://192.168.5.103:8081/repository/helm-hosted/ 2>/dev/null || true
helm repo update helm-hosted 2>/dev/null
echo "       完成"

# ── 2. 创建命名空间 ──
echo ""
echo "[2/5] 创建命名空间"
kubectl create ns "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
echo "       完成"

# ── 3. 安装 KubeBlocks CRD ──
echo ""
echo "[3/5] 安装 KubeBlocks CRD"
CRD_BASE_URL="https://gh-proxy.com/https://raw.githubusercontent.com/apecloud/kubeblocks/main/config/crd/bases"
for crd_file in \
  apps.kubeblocks.io_clusterdefinitions.yaml apps.kubeblocks.io_clusters.yaml \
  apps.kubeblocks.io_componentdefinitions.yaml apps.kubeblocks.io_components.yaml \
  apps.kubeblocks.io_componentversions.yaml workloads.kubeblocks.io_instancesets.yaml \
  workloads.kubeblocks.io_instances.yaml extensions.kubeblocks.io_addons.yaml \
  operations.kubeblocks.io_opsdefinitions.yaml operations.kubeblocks.io_opsrequests.yaml; do
  curl -sL --connect-timeout 10 --max-time 30 "$CRD_BASE_URL/$crd_file" | kubectl apply --server-side=true -f - 2>/dev/null || true
done
echo "       完成"

# ── 4. 安装 KubeBlocks ──
echo ""
echo "[4/5] 安装 KubeBlocks v${CHART_VERSION}"
helm upgrade --install "$RELEASE_NAME" helm-hosted/"$CHART_NAME" \
  --namespace "$NAMESPACE" \
  --version "$CHART_VERSION" \
  --values "$SCRIPT_DIR/values.yaml" \
  --timeout 10m \
  --wait
echo "       完成"

# ── 5. 配置 addon installer RBAC 并等待 addon ──
echo ""
echo "[5/5] 配置 addon installer RBAC"
kubectl create serviceaccount kubeblocks-addon-installer -n "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null
kubectl apply -f - <<'EOF' 2>/dev/null
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kubeblocks-addon-installer-binding
  labels:
    app.kubernetes.io/name: kubeblocks
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: kubeblocks-addon-installer
  namespace: operators
EOF
echo "       等待 addon 自动安装..."
sleep 30

# 若 addon 未自动就绪，手动安装 addon chart
if ! kubectl get componentdefinition -A 2>/dev/null | grep -q apecloud-mysql; then
  echo "       手动安装 apecloud-mysql addon chart..."
  curl -sL --connect-timeout 10 --max-time 30 "http://192.168.5.103:8081/repository/helm-hosted/apecloud-mysql-1.0.1.tgz" -o /tmp/apecloud-mysql-1.0.1.tgz 2>/dev/null
  helm upgrade --install kb-addon-apecloud-mysql /tmp/apecloud-mysql-1.0.1.tgz -n "$NAMESPACE" --timeout 5m --wait 2>/dev/null || true
fi
if ! kubectl get componentdefinition -A 2>/dev/null | grep -q redis-7; then
  echo "       手动安装 redis addon chart..."
  curl -sL --connect-timeout 10 --max-time 30 "http://192.168.5.103:8081/repository/helm-hosted/redis-1.0.2.tgz" -o /tmp/redis-1.0.2.tgz 2>/dev/null
  helm upgrade --install kb-addon-redis /tmp/redis-1.0.2.tgz -n "$NAMESPACE" --timeout 5m --wait 2>/dev/null || true
fi

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
echo "下一步: 部署 MySQL / Redis 集群"
echo "  cd ../mysql/kubeblocks && bash install.sh"
echo "  cd ../redis/kubeblocks && bash install.sh"
