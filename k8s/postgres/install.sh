#!/bin/bash
# install.sh — PostgreSQL 17 实例部署
# 用法: bash install.sh [standalone|ha]
# 前置条件: operators/cnpg/install.sh 已执行
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-standalone}"
PG_NS="postgres"

# 创建命名空间 + 配额
kubectl create namespace "$PG_NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "$SCRIPT_DIR/resourcequota.yaml"

# 公共 Secret（数据库密码）
kubectl apply -f "$SCRIPT_DIR/operator/common/"

# 应用实例 CR
kubectl apply -f "$SCRIPT_DIR/operator/$MODE/"

echo ""
echo "✅ PostgreSQL $MODE 部署完成"
echo "   命名空间: $PG_NS"
echo "   连接: psql -h pg-${MODE}-rw.${PG_NS}.svc.cluster.local -U postgres -d appdb"
echo "   密码: postgres@123"
echo "   查看: kubectl get cluster -n $PG_NS"
