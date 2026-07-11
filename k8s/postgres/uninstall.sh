#!/bin/bash
# uninstall.sh — PostgreSQL 17 实例卸载
# 用法: bash uninstall.sh [standalone|ha|all]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PG_NS="postgres"
MODE="${1:-standalone}"

case "$MODE" in
  standalone|ha)
    echo ">> 删除 $MODE Cluster CR ..."
    for f in $(ls -r "$SCRIPT_DIR/operator/$MODE/" 2>/dev/null); do
      kubectl delete -f "$SCRIPT_DIR/operator/$MODE/$f" --grace-period=30 2>/dev/null || true
    done
    echo ">> 等待 Pod 终止 ..."
    sleep 15
    kubectl get pvc -n "$PG_NS" 2>/dev/null | grep "^pg-$MODE" | awk '{print $1}' | xargs -r kubectl delete pvc -n "$PG_NS" --grace-period=10 2>/dev/null || true
    echo "✅ $MODE 实例已删除"
    ;;
  all)
    for f in $(ls -r "$SCRIPT_DIR/operator/standalone/" 2>/dev/null); do
      kubectl delete -f "$SCRIPT_DIR/operator/standalone/$f" --grace-period=30 2>/dev/null || true
    done
    for f in $(ls -r "$SCRIPT_DIR/operator/ha/" 2>/dev/null); do
      kubectl delete -f "$SCRIPT_DIR/operator/ha/$f" --grace-period=30 2>/dev/null || true
    done
    kubectl delete -f "$SCRIPT_DIR/operator/common/" 2>/dev/null || true
    sleep 15
    kubectl get pvc -n "$PG_NS" 2>/dev/null | grep "^pg-" | awk '{print $1}' | xargs -r kubectl delete pvc -n "$PG_NS" --grace-period=10 2>/dev/null || true
    kubectl delete namespace "$PG_NS" --grace-period=30 2>/dev/null || true
    echo "✅ PostgreSQL 实例已完全卸载"
    ;;
  *)
    echo "❌ 用法: $0 [standalone|ha|all]"
    exit 1
    ;;
esac
