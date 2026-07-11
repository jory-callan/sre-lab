#!/bin/bash
# install.sh -- 安装 ingress-nginx
# 用法: bash install.sh
# 前置条件: Cilium + MetalLB 已就绪，kubectl 连接正常
set -euo pipefail

INGRESS_VERSION="4.15.1"
MIRROR_BASE="${MIRROR_BASE:-https://gh-proxy.com}"
CHART_FILE="$(cd "$(dirname "$0")" && pwd)/ingress-nginx-${INGRESS_VERSION}.tgz"
NAMESPACE="ingress-nginx"
RELEASE="ingress-nginx"

# ── 前置检查：MetalLB IPAddressPool ──────────────────────────────
if ! kubectl get ipaddresspool -n metallb-system -o name 2>/dev/null | grep -q .; then
    POOL_FILE="$(cd "$(dirname "$0")/../metallb" && pwd)/pool.yaml"
    if [ -f "$POOL_FILE" ]; then
        echo ">> MetalLB IPAddressPool 未配置，自动 apply pool.yaml ..."
        kubectl apply -f "$POOL_FILE"
    else
        echo "[WARN] MetalLB pool.yaml 未找到，请手动配置 IPAddressPool"
    fi
fi

# ── 检查 helm release 状态 ──────────────────────────────────────
HELM_STATUS=$(helm list -n "$NAMESPACE" --filter "$RELEASE" -o json 2>/dev/null | jq -r '.[0].status // "not-found"')

if [ "$HELM_STATUS" = "deployed" ]; then
    echo "[INFO] ingress-nginx 已安装且状态正常，跳过"
    exit 0
elif [ "$HELM_STATUS" = "failed" ]; then
    echo "[INFO] ingress-nginx 上次安装失败，执行 helm upgrade 修复 ..."
elif [ "$HELM_STATUS" = "not-found" ]; then
    echo ">> 安装 ingress-nginx ..."
fi

# ── 下载 chart ──────────────────────────────────────────────────
if [ ! -f "$CHART_FILE" ]; then
    echo ">> 本地 chart 未找到，下载 ingress-nginx ${INGRESS_VERSION} ..."
    local_url="${MIRROR_BASE:+"${MIRROR_BASE}/"}https://github.com/kubernetes/ingress-nginx/releases/download/helm-chart-${INGRESS_VERSION}/ingress-nginx-${INGRESS_VERSION}.tgz"
    curl -fsSL "$local_url" -o "$CHART_FILE" --connect-timeout 30 --retry 3
fi

# ── 安装/升级 ────────────────────────────────────────────────────
echo ">> 安装 ingress-nginx (DaemonSet + LoadBalancer 模式)..."
helm upgrade --install "$RELEASE" "$CHART_FILE" \
    --namespace "$NAMESPACE" --create-namespace \
    --set controller.kind=DaemonSet \
    --set controller.service.type=LoadBalancer \
    --set controller.service.externalTrafficPolicy=Local \
    --set controller.service.nodePorts.http=30080 \
    --set controller.service.nodePorts.https=30443 \
    --set controller.admissionWebhooks.enabled=true \
    --set controller.metrics.enabled=false \
    --set controller.config.compute-full-forwarded-for="true" \
    --set controller.config.use-forwarded-headers="true" \
    --set controller.config.worker-processes="auto" \
    --set controller.config.proxy-body-size="100m" \
    --set controller.progressDeadlineSeconds=600 \
    --wait --timeout 5m

echo "[OK] ingress-nginx 安装完成"
echo ""
echo "   查看分配的 LoadBalancer IP:"
echo "     kubectl -n ingress-nginx get svc ingress-nginx-controller"
echo ""
echo "   配置 DNS 将 *.czw-sre.internal 指向上述 IP"
echo ""
echo "   验证:"
echo "     curl -H 'Host: test.czw-sre.internal' http://<LB_IP>"
echo "     curl http://<任意节点IP>:30080"
