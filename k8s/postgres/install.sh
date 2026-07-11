#!/bin/bash
# install.sh — PostgreSQL 17 实例部署
# 用法: bash install.sh [standalone|ha]
# 前置条件: operators/cnpg/install.sh 已执行, MinIO 已部署（S3 备份依赖）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-ha}"          # 默认 1 主 2 从（HA）
PG_NS="postgres"

# ── 初始化 ──────────────────────────────────────────
kubectl create namespace "$PG_NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "$SCRIPT_DIR/resourcequota.yaml"

# 公共 Secret（数据库密码 + S3 备份凭证）
kubectl apply -f "$SCRIPT_DIR/operator/common/"

# ── S3 备份：在 MinIO 上创建备份用户 ────────────────
MINIO_POD=$(kubectl -n minio get pod -l v1.min.io/tenant=minio -o name 2>/dev/null | head -1)
if [ -n "$MINIO_POD" ]; then
  echo ">> 配置 MinIO S3 备份用户 ..."
  kubectl -n minio exec "$MINIO_POD" -c minio -- mc alias set local http://localhost:9000 minioadmin minioadmin 2>/dev/null || true
  # 将 policy JSON 写入 MinIO Pod
  kubectl -n minio exec -i "$MINIO_POD" -c minio -- sh -c 'cat > /tmp/pg-backup-policy.json' < "$SCRIPT_DIR/backup-policy.json" 2>/dev/null
  kubectl -n minio exec "$MINIO_POD" -c minio -- mc admin policy create local pg-backup /tmp/pg-backup-policy.json 2>/dev/null || true
  kubectl -n minio exec "$MINIO_POD" -c minio -- mc admin user add local pg-backup Z6rX9pLm8kQw4nSv 2>/dev/null || true
  kubectl -n minio exec "$MINIO_POD" -c minio -- mc admin policy attach local pg-backup --user=pg-backup 2>/dev/null || true
  echo "   MinIO 备份用户已就绪"
else
  echo "   ⚠️  MinIO 不可用，跳过 S3 备份配置"
fi

# ── 应用实例 CR ──────────────────────────────────────
kubectl apply -f "$SCRIPT_DIR/operator/$MODE/"

# ── 告警规则 ───────────────────────────────────────────
kubectl apply -f "$SCRIPT_DIR/monitor/rule/"

# ── 输出 ──────────────────────────────────────────────
echo ""
echo "✅ PostgreSQL $MODE 部署完成"
echo ""

case "$MODE" in
  ha)
    CLUSTER="pg-ha"
    NODE_PORT="30006"
    ;;
  standalone)
    CLUSTER="pg-standalone"
    NODE_PORT="30205"
    ;;
esac

echo "   ┌─ 访问入口 ─────────────────────────────────────────────────┐"
echo "   │                                                            │"
echo "   │   内部（推荐）                                             │"
echo "   │     读写: ${CLUSTER}-rw.${PG_NS}.svc:5432                  │"
echo "   │     只读: ${CLUSTER}-ro.${PG_NS}.svc:5432                  │"
echo "   │     均衡: ${CLUSTER}-r.${PG_NS}.svc:5432                   │"
echo "   │                                                            │"
echo "   │   外部（NodePort）                                         │"
echo "   │     ${CLUSTER}: <node-ip>:${NODE_PORT}                     │"
echo "   └────────────────────────────────────────────────────────────┘"
echo ""
echo "   ┌─ 凭证 ─────────────────────────────────────────────────────┐"
echo "   │   postgres: kubectl get secret ${CLUSTER}-app              │"
echo "   │             -n ${PG_NS} -o jsonpath='"'"'{.data.password}'"'"' | base64 -d │"
echo "   │   superuser: kubectl get secret ${CLUSTER}-superuser       │"
echo "   │             -n ${PG_NS} -o jsonpath='"'"'{.data.password}'"'"' | base64 -d │"
echo "   └────────────────────────────────────────────────────────────┘"

if [ "$MODE" = "ha" ]; then
  echo ""
  echo "   ┌─ 备份 ───────────────────────────────────────────────────┐"
  echo "   │   每天 03:00 自动全量备份 → MinIO postgres-backup bucket  │"
  echo "   │   保留 30 天                                              │"
  echo "   │   手动触发: kubectl cnpg backup ${CLUSTER} -n ${PG_NS}   │"
  echo "   │   查看备份: kubectl get backup -n ${PG_NS}                │"
  echo "   └──────────────────────────────────────────────────────────┘"
fi

echo ""
echo "   ┌─ 常用操作 ────────────────────────────────────────────────┐"
echo "   │   查看: kubectl get cluster -n ${PG_NS}                    │"
echo "   │   日志: kubectl logs -n ${PG_NS} -l cnpg.io/cluster=${CLUSTER} -c postgres │"
echo "   │   psql: kubectl exec -n ${PG_NS} -it ${CLUSTER}-1 -- psql  │"
echo "   └────────────────────────────────────────────────────────────┘"
