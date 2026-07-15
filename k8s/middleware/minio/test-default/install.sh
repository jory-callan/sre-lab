#!/bin/bash
# install.sh — MinIO Tenant 测试实例（生产使用）
# Usage: bash install.sh [install|uninstall|purge]
#   install    部署 MinIO Tenant（幂等）
#   uninstall  卸载 Tenant，保留 PVC
#   purge      完全卸载干净
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MINIO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ===== 配置区 =====
NAME="minio"
NAMESPACE="minio"
OPERATOR_NS="operators"
# ===================

_wait_pod() {
  echo ">> 等待 MinIO Pod 就绪 ..."
  local retries=30
  while [ $retries -gt 0 ]; do
    local pod
    pod=$(kubectl -n "$NAMESPACE" get pod -l v1.min.io/tenant=minio -o name 2>/dev/null | head -1)
    if [ -n "$pod" ]; then
      local ready
      ready=$(kubectl -n "$NAMESPACE" get "$pod" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
      if [ "$ready" = "True" ]; then
        echo "   Pod $pod 就绪"
        return 0
      fi
    fi
    sleep 2
    retries=$((retries - 1))
  done
  echo "   ⚠️  MinIO Pod 未就绪，跳过后续配置"
  return 1
}

_post_deploy() {
  _wait_pod || return 0
  local pod
  pod=$(kubectl -n "$NAMESPACE" get pod -l v1.min.io/tenant=minio -o name 2>/dev/null | head -1)
  [ -z "$pod" ] && return 0

  # 配置 mc alias
  kubectl -n "$NAMESPACE" exec "$pod" -c minio -- mc alias set L http://localhost:9000 minioadmin minioadmin 2>/dev/null

  # 创建 bucket（幂等）
  for b in public private velero vm-metrics vm-logs postgres-backup; do
    kubectl -n "$NAMESPACE" exec "$pod" -c minio -- mc mb L/"$b" 2>/dev/null || true
  done

  # 配置 svc-poweruser 策略
  kubectl -n "$NAMESPACE" exec "$pod" -c minio -- mc admin policy detach L consoleAdmin --user=svc-poweruser 2>/dev/null || true
  kubectl -n "$NAMESPACE" exec "$pod" -c minio -- mc admin policy attach L readwrite --user=svc-poweruser 2>/dev/null || true

  # 配置 svc-private 策略
  local PF="/tmp/private-rw.json"
  kubectl -n "$NAMESPACE" exec "$pod" -c minio -- sh -c "cat > $PF << 'JSON'
{
  \"Version\": \"2012-10-17\",
  \"Statement\": [
    {\"Effect\": \"Allow\",\"Action\": [\"s3:ListBucket\"],\"Resource\": [\"arn:aws:s3:::private\"]},
    {\"Effect\": \"Allow\",\"Action\": [\"s3:GetObject\",\"s3:PutObject\",\"s3:DeleteObject\"],\"Resource\": [\"arn:aws:s3:::private/*\"]}
  ]
}
JSON" 2>/dev/null || true
  kubectl -n "$NAMESPACE" exec "$pod" -c minio -- mc admin policy create L private-rw "$PF" 2>/dev/null || true
  kubectl -n "$NAMESPACE" exec "$pod" -c minio -- mc admin policy detach L consoleAdmin --user=svc-private 2>/dev/null || true
  kubectl -n "$NAMESPACE" exec "$pod" -c minio -- mc admin policy attach L private-rw --user=svc-private 2>/dev/null || true
}

install() {
  # 1. 确保 operator 已安装
  if ! helm list -n "$OPERATOR_NS" 2>/dev/null | grep -q minio-operator; then
    echo ">> MinIO Operator 未安装，先安装 operator ..."
    bash "$MINIO_DIR/operator/install.sh" install
  fi

  # 2. 创建命名空间
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

  # 3. 部署核心资源
  kubectl apply -f "$SCRIPT_DIR/secret-root.yaml"
  kubectl apply -f "$SCRIPT_DIR/secret-poweruser.yaml"
  kubectl apply -f "$SCRIPT_DIR/secret-private.yaml"
  kubectl apply -f "$SCRIPT_DIR/cr-tenant.yaml"

  # 4. Ingress
  kubectl apply --validate=false -f "$SCRIPT_DIR/service-ingress-api.yaml"
  kubectl apply --validate=false -f "$SCRIPT_DIR/service-ingress-console.yaml"

  # 5. ServiceMonitor（可选，监控栈未部署时忽略错误）
  kubectl apply -f "$MINIO_DIR/common/monitor/service-monitor.yaml" 2>/dev/null || true

  # 6. 给 Service 打 label（ServiceMonitor 需要）
  kubectl label svc -n "$NAMESPACE" minio minio-console app=minio --overwrite 2>/dev/null || true

  # 7. 后置配置（创建 bucket + 用户策略）
  _post_deploy

  echo ""
  echo "✅ MinIO Tenant 部署完成"
  echo "   S3 API:   https://minio-api.czw-sre.internal"
  echo "   Console:  https://minio.czw-sre.internal"
  echo "   root:     minioadmin / minioadmin"
  echo "   Pod:      kubectl -n $NAMESPACE get pods"
}

uninstall() {
  # 卸载 Tenant，保留 PVC
  kubectl delete tenant minio -n "$NAMESPACE" --ignore-not-found --wait=true 2>/dev/null || true
  echo "✅ Tenant 已卸载（PVC 保留）"
}

purge() {
  kubectl delete tenant minio -n "$NAMESPACE" --ignore-not-found --wait=true 2>/dev/null || true
  kubectl delete pvc -n "$NAMESPACE" --all --ignore-not-found 2>/dev/null || true
  kubectl delete namespace "$NAMESPACE" --ignore-not-found
  echo "✅ Tenant 已完全清理"
}

case "${1:-install}" in
  install) install ;;
  uninstall) uninstall ;;
  purge) purge ;;
  *) echo "Usage: $0 [install|uninstall|purge]"; exit 1 ;;
esac
