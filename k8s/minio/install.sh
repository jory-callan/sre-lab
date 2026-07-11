#!/bin/bash
# install.sh — MinIO 对象存储 (MinIO Operator)
# 用法: bash install.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPERATOR_NS="operators"
TENANT_NS="minio"
CHART_VERSION="7.1.1"
CHART_FILE="$SCRIPT_DIR/minio-operator-${CHART_VERSION}.tgz"

# 下载 operator chart
if [ ! -f "$CHART_FILE" ]; then
  echo ">> 下载 MinIO Operator chart ${CHART_VERSION} ..."
  helm repo add minio-operator https://operator.min.io/ 2>/dev/null || true
  helm pull minio-operator/operator --version "$CHART_VERSION" --destination "$SCRIPT_DIR/"
  mv "$SCRIPT_DIR/operator-${CHART_VERSION}.tgz" "$CHART_FILE" 2>/dev/null || true
fi

# 安装 operator
if ! helm list -n "$OPERATOR_NS" 2>/dev/null | grep -q minio-operator; then
  echo ">> 安装 MinIO Operator ..."
  helm upgrade --install minio-operator "$CHART_FILE" \
    --namespace "$OPERATOR_NS" --create-namespace \
    --timeout 5m --wait
fi

# 创建 tenant namespace + 应用核心资源
kubectl create namespace "$TENANT_NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "$SCRIPT_DIR/secret.yaml" -f "$SCRIPT_DIR/secret-poweruser.yaml" -f "$SCRIPT_DIR/secret-private.yaml" -f "$SCRIPT_DIR/tenant.yaml"
kubectl apply -f "$SCRIPT_DIR/ingress.yaml" -f "$SCRIPT_DIR/console-ingress.yaml"

# 可选：ServiceMonitor（监控栈未部署时忽略）
kubectl apply -f "$SCRIPT_DIR/service-monitor.yaml" 2>/dev/null || true

# ── 用户策略配置 ────────────────────────────────
# Tenant CRD 创建的用户默认 consoleAdmin，需调整为实际所需权限
POD=""
for i in $(seq 1 30); do
  POD=$(kubectl -n "$TENANT_NS" get pod -l app=minio -o name 2>/dev/null | head -1)
  [ -n "$POD" ] && break
  sleep 2
done

if [ -n "$POD" ]; then
  echo ">> 配置用户策略 ..."
  # 等待 mc 就绪
  sleep 5
  kubectl -n "$TENANT_NS" exec "$POD" -c minio -- mc alias set local http://localhost:9000 minioadmin minioadmin 2>/dev/null

  # svc-poweruser → readwrite（所有 bucket 读写）
  kubectl -n "$TENANT_NS" exec "$POD" -c minio -- mc admin policy detach local consoleAdmin --user=svc-poweruser 2>/dev/null || true
  kubectl -n "$TENANT_NS" exec "$POD" -c minio -- mc admin policy attach local readwrite --user=svc-poweruser 2>/dev/null

  # svc-private → private-rw（仅 private bucket 读写）
  kubectl -n "$TENANT_NS" exec "$POD" -c minio -- sh -c 'cat > /tmp/private-rw.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": ["arn:aws:s3:::private"]
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": ["arn:aws:s3:::private/*"]
    }
  ]
}
EOF' 2>/dev/null
  kubectl -n "$TENANT_NS" exec "$POD" -c minio -- mc admin policy create local private-rw /tmp/private-rw.json 2>/dev/null || true
  kubectl -n "$TENANT_NS" exec "$POD" -c minio -- mc admin policy detach local consoleAdmin --user=svc-private 2>/dev/null || true
  kubectl -n "$TENANT_NS" exec "$POD" -c minio -- mc admin policy attach local private-rw --user=svc-private 2>/dev/null
fi

echo ""
echo "✅ MinIO 部署完成"
echo "   API: https://minio-api.czw-sre.internal"
echo "   Console: https://minio.czw-sre.internal"
echo "   账号: minioadmin / minioadmin"
echo "   查看: kubectl -n $TENANT_NS get pods"
