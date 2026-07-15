#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NAMESPACE="mysql"
CLUSTER_NAME="mysql-kb"

echo "=============================="
echo "MySQL Cluster (KubeBlocks) 部署"
echo "=============================="
echo ""

# ── 1. 创建命名空间 ──
echo "[1/3] 创建命名空间"
kubectl create ns "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
echo "       完成"

# ── 2. 创建集群 ──
echo ""
echo "[2/3] 创建 MySQL Cluster CR（1主2从）"
kubectl apply -f "$SCRIPT_DIR/cluster.yaml"
echo "       完成"

# ── 3. 等待就绪 ──
echo ""
echo "[3/3] 等待集群就绪（约 3-5 分钟）..."
kubectl wait --for=condition=Available cluster/$CLUSTER_NAME -n "$NAMESPACE" --timeout=600s 2>/dev/null || echo "       等待超时，请手动检查: kubectl get cluster -n $NAMESPACE -w"

echo ""
echo "=============================="
echo "MySQL 部署完成"
echo "=============================="
echo ""
echo "连接信息:"
echo "  集群内: mysql -h mysql-kb-mysql-0.mysql-kb-mysql.${NAMESPACE}.svc.cluster.local -u root -p'root@czw123'"
echo ""
echo "查看状态:"
echo "  kubectl get pods -n $NAMESPACE -l app.kubernetes.io/instance=$CLUSTER_NAME"
echo "  kubectl get cluster -n $NAMESPACE $CLUSTER_NAME -o wide"
echo ""
echo "验证:"
echo "  kubectl exec -n $NAMESPACE ${CLUSTER_NAME}-mysql-0 -- mysql -uroot -proot@czw123 -e \"SHOW STATUS LIKE 'wsrep_cluster_size'\""
