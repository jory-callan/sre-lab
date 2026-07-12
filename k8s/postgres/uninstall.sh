#!/bin/bash
# uninstall.sh — PostgreSQL 17 实例卸载
# 用法: bash uninstall.sh [standalone|ha|all]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PG_NS="postgres"
MODE="${1:-standalone}"

stop_cluster() {
  local mode="$1"
  echo ">> 删除 $mode Cluster CR ..."
  kubectl delete cluster -n "$PG_NS" "pg-${mode}" --grace-period=30 --timeout=60s 2>/dev/null || true
  echo ">> 等待 Pod 终止 ..."
  sleep 15
  echo ">> 删除 $mode 关联的 PVC ..."
  kubectl get pvc -n "$PG_NS" 2>/dev/null | grep "^pg-${mode}" | awk '{print $1}' | xargs -r kubectl delete pvc -n "$PG_NS" --grace-period=10 --timeout=30s 2>/dev/null || true
  echo ">> 删除 $mode 关联的 Service ..."
  kubectl get svc -n "$PG_NS" 2>/dev/null | grep "^pg-${mode}" | awk '{print $1}' | xargs -r kubectl delete svc -n "$PG_NS" --timeout=10s 2>/dev/null || true
  echo ">> 删除 $mode 关联的 ScheduledBackup ..."
  kubectl get scheduledbackup -n "$PG_NS" 2>/dev/null | grep "^pg-${mode}" | awk '{print $1}' | xargs -r kubectl delete scheduledbackup -n "$PG_NS" --timeout=10s 2>/dev/null || true
  echo ">> 删除 $mode 关联的 PodMonitor ..."
  kubectl get podmonitor -n "$PG_NS" 2>/dev/null | grep "^pg-${mode}" | awk '{print $1}' | xargs -r kubectl delete podmonitor -n "$PG_NS" --timeout=10s 2>/dev/null || true
  echo ">> 删除 $mode 生成的证书 Secret ..."
  kubectl get secret -n "$PG_NS" 2>/dev/null | grep "^pg-${mode}-" | awk '{print $1}' | xargs -r kubectl delete secret -n "$PG_NS" --timeout=10s 2>/dev/null || true
  echo "✅ $mode 实例已删除"
}

case "$MODE" in
  standalone|ha)
    stop_cluster "$MODE"
    ;;
  all)
    stop_cluster "standalone"
    stop_cluster "ha"
    kubectl delete -f "$SCRIPT_DIR/cr/common/" --timeout=10s 2>/dev/null || true
    kubectl delete -f "$SCRIPT_DIR/dep-minio/pg-s3-creds.yaml" --timeout=10s 2>/dev/null || true
    kubectl delete -f "$SCRIPT_DIR/resourcequota.yaml" --timeout=10s 2>/dev/null || true
    kubectl delete namespace "$PG_NS" --grace-period=30 --timeout=60s 2>/dev/null || true
    echo "✅ PostgreSQL 实例已完全卸载"
    ;;
  *)
    echo "❌ 用法: $0 [standalone|ha|all]"
    exit 1
    ;;
esac
