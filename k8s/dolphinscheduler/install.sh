#!/bin/bash
# install.sh — DolphinScheduler + SeaTunnel Engine 一键部署
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NS="dolphinscheduler"

echo "========================================="
echo " DolphinScheduler + SeaTunnel Engine 部署"
echo "========================================="

# 1. 命名空间
echo ">> 创建命名空间 ${NS} ..."
kubectl create namespace "${NS}" --dry-run=client -o yaml | kubectl apply -f -

# 2. ZooKeeper
echo ">> 部署 ZooKeeper ..."
kubectl apply -f "${SCRIPT_DIR}/zookeeper/zookeeper.yaml"
kubectl rollout status statefulset/ds-zookeeper -n "${NS}" --timeout=180s

# 3. DolphinScheduler
echo ">> 部署 DolphinScheduler (Helm) ..."
helm upgrade --install ds "${SCRIPT_DIR}/dolphinscheduler/chart" \
  --namespace "${NS}" \
  --values "${SCRIPT_DIR}/dolphinscheduler/values.yaml" \
  --timeout 30m

# 4. SeaTunnel Engine
echo ">> 部署 SeaTunnel Engine (Helm) ..."
helm upgrade --install st "${SCRIPT_DIR}/seatunnel-engine" \
  --namespace "${NS}" \
  --timeout 5m

# 5. 等待 Pod 就绪
echo ">> 等待 Pod 就绪 ..."
for sts in ds-master ds-worker ds-zookeeper; do
  kubectl rollout status statefulset/"${sts}" -n "${NS}" --timeout=300s 2>/dev/null || true
done
for deploy in ds-api ds-alert; do
  kubectl rollout status deployment/"${deploy}" -n "${NS}" --timeout=300s 2>/dev/null || true
done
kubectl rollout status statefulset/st -n "${NS}" --timeout=300s 2>/dev/null || true

# 6. 输出
echo ""
echo "✅ 部署完成"
echo ""
echo "   ZooKeeper:   ds-zookeeper.${NS}.svc:2181"
echo "   DS API:      ds-api.${NS}.svc:12345"
echo "   DS UI:       kubectl port-forward -n ${NS} svc/ds-api 12345:12345"
echo "                -> http://127.0.0.1:12345/dolphinscheduler"
echo "   SeaTunnel:   st.${NS}.svc:5802"
echo ""
echo "   查看 Pod: kubectl get pods -n ${NS}"
