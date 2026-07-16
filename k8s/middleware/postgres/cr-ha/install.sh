#!/bin/bash
# install.sh — PostgreSQL HA 实例（1 主 2 从 + PgBouncer + S3 备份）
# Usage: bash install.sh [install|uninstall|purge]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== 配置区 =====
NAME="pg-ha"
NAMESPACE="postgres"
CHART="$SCRIPT_DIR/../chart"
VALUES="$SCRIPT_DIR/values.yaml"
# ==================

install() {
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  # 标记 Helm ownership，使 chart 中的 namespace.yaml 可以接管
  kubectl label namespace "$NAMESPACE" app.kubernetes.io/managed-by=Helm --overwrite 2>/dev/null || true
  kubectl annotate namespace "$NAMESPACE" meta.helm.sh/release-name="$NAME" --overwrite 2>/dev/null || true
  kubectl annotate namespace "$NAMESPACE" meta.helm.sh/release-namespace="$NAMESPACE" --overwrite 2>/dev/null || true

  # 前置依赖：MinIO 备份桶和用户（幂等）
  bash "$SCRIPT_DIR/dep-minio-setup.sh" 2>/dev/null || true

  # 前置依赖：共享 Secret（幂等，kubectl apply 确保 Helm 释放间共享）
  kubectl apply -f "$SCRIPT_DIR/cr-secret.yaml" --namespace "$NAMESPACE"
  kubectl apply -f "$SCRIPT_DIR/dep-minio-pg-s3-creds.yaml" --namespace "$NAMESPACE"

  # Helm 部署 Cluster / Pooler / ScheduledBackup / Service
  helm upgrade --install "$NAME" "$CHART" \
    --namespace "$NAMESPACE" \
    --values "$VALUES" \
    --timeout 5m --wait

  # PodMonitor（monitoring CRD 可能未安装，允许失败）
  kubectl apply -f "$SCRIPT_DIR/cr-pod-monitor.yaml" --namespace "$NAMESPACE" 2>/dev/null || \
    echo "  ⚠️  PodMonitor 未安装（monitoring.coreos.com CRD 缺失）"

  # 设置 superuser 密码（CNPG 1.29+ bootstrap 不自动设置）
  set_superuser_password
}

set_superuser_password() {
  echo ">> 设置 superuser 密码..."
  # 等待集群就绪
  kubectl wait --for=condition=Ready "cluster/$NAME" -n "$NAMESPACE" --timeout=300s 2>/dev/null || true
  # 找到 primary pod 执行密码设置
  local primary
  primary=$(kubectl get pod -n "$NAMESPACE" -l "cnpg.io/cluster=$NAME,cnpg.io/podRole=instance" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -n "$primary" ]; then
    kubectl exec -n "$NAMESPACE" "$primary" -- psql -U postgres -d postgres \
      -c "ALTER USER postgres WITH PASSWORD 'postgres@czw123';" 2>/dev/null && \
      echo "   ✅ superuser 密码已设置" || echo "   ⚠️  密码设置失败（不影响已有的密码）"
  fi
}

uninstall() {
  # 卸载服务，保留 PVC / PV / 数据
  helm uninstall "$NAME" --namespace "$NAMESPACE"
}

purge() {
  # 完全卸载
  helm uninstall "$NAME" --namespace "$NAMESPACE" 2>/dev/null || true
  kubectl delete namespace "$NAMESPACE" --ignore-not-found
}

case "${1:-install}" in
  install) install ;;
  uninstall) uninstall ;;
  purge) purge ;;
  *) echo "Usage: $0 [install|uninstall|purge]"; exit 1 ;;
esac
