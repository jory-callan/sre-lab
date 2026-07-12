#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=============================="
echo "redis-core 卸载"
echo "=============================="
echo ""

# 1. 删除 CR（级联删除 StatefulSet/Deployment/PVC/Service）
echo "[1/3] 删除 RedisFailover CR..."
kubectl delete -f "$SCRIPT_DIR/cr/sentinel-ha/redis-failover.yaml" --ignore-not-found --timeout=60s 2>/dev/null || true
kubectl delete -f "$SCRIPT_DIR/cr/sentinel-ha/service-external.yaml" --ignore-not-found 2>/dev/null || true
kubectl delete -f "$SCRIPT_DIR/cr/sentinel-ha/backup-cronjob.yaml" --ignore-not-found 2>/dev/null || true
sleep 5

# 2. 删除 Secret + 命名空间
echo "[2/3] 清理命名空间 redis..."
kubectl delete ns redis --ignore-not-found --timeout=60s 2>/dev/null || true

# 3. 删除 Operator（CRD + RBAC + Deployment）
echo "[3/3] 删除 Operator..."
kubectl delete -f "$SCRIPT_DIR/operator/spotahome/00-operator.yaml" --ignore-not-found --timeout=60s 2>/dev/null || true

echo ""
echo "完成！"
echo ""
echo "如需保留 Operator 供其他 CR 使用，跳过 [3/3]:"
echo "  kubectl delete -f operator/spotahome/00-operator.yaml  # 只删 operator"
echo "  kubectl delete ns redis                                # 只删 redis 数据"
