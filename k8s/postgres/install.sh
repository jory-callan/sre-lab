#!/bin/bash
# install.sh — PostgreSQL 17 实例部署
# 用法: bash install.sh [ha|standalone]
# 依赖: operators/cnpg/install.sh, MinIO（S3 备份）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-ha}"
PG_NS="postgres"

# ── 初始化 ──────────────────────────────────────────
kubectl create namespace "$PG_NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "$SCRIPT_DIR/resourcequota.yaml"
kubectl apply -f "$SCRIPT_DIR/operator/common/"

# ── MinIO 备份依赖（桶 / 用户 / S3 凭证）────────────
kubectl apply -f "$SCRIPT_DIR/minio/pg-s3-creds.yaml"
bash "$SCRIPT_DIR/minio/setup.sh"

# ── 实例 CR + 告警规则 ─────────────────────────────
kubectl apply -f "$SCRIPT_DIR/operator/$MODE/"
kubectl apply -f "$SCRIPT_DIR/monitor/rule/"

# ── 输出 ──────────────────────────────────────────────
echo ""
echo "✅ PostgreSQL $MODE 部署完成"
echo ""

case "$MODE" in
  ha)   CLUSTER="pg-ha";     NPORT="30006" ;;
  standalone) CLUSTER="pg-standalone"; NPORT="30205" ;;
esac

echo "   内部: ${CLUSTER}-rw.${PG_NS}.svc:5432（读写）"
echo "   外部: <node-ip>:${NPORT}"
echo ""
echo "   查询: kubectl get cluster -n ${PG_NS}"
echo "   psql: kubectl exec -n ${PG_NS} -it ${CLUSTER}-1 -- psql"
echo "   交付: ${CLUSTER} 的全部信息见 DELIVERY.md"

if [ "$MODE" = "ha" ]; then
  echo ""
  echo "   备份: 每天 03:00 全量 → MinIO（保留 30 天）"
  echo "   手动: kubectl cnpg backup ${CLUSTER} -n ${PG_NS}"
fi
echo ""
