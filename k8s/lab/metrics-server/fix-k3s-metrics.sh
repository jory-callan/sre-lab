#!/bin/bash
set -euo pipefail

# 修复 k3s 内置 metrics-server Service selector 与 Pod labels 不匹配的问题
# Service 原始 selector 是 app.kubernetes.io/instance 和 app.kubernetes.io/name
# 但 Pod 只有 k8s-app 这个 label，导致 endpoints 为空

kubectl patch svc metrics-server -n kube-system --type='json' \
  -p='[{"op": "replace", "path": "/spec/selector", "value": {"k8s-app": "metrics-server"}}]'

echo "[OK] metrics-server Service selector 已修复"
sleep 3
kubectl top node && echo "[OK] metrics API 正常" || echo "[WARN] 稍等几秒再试 kubectl top node"
