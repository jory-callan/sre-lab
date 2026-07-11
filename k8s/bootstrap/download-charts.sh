#!/bin/bash
# download-charts.sh — 下载所有 Helm chart 到本地 charts/ 目录
# 用法: bash download-charts.sh
# 环境变量: MIRROR_BASE (默认: https://gh-proxy.com)
#           如需直连 GitHub，设为空字符串: MIRROR_BASE="" bash download-charts.sh
set -euo pipefail

MIRROR_BASE="${MIRROR_BASE:-https://gh-proxy.com}"
CHARTS_DIR="$(cd "$(dirname "$0")" && pwd)/charts"
mkdir -p "$CHARTS_DIR"

download_chart() {
    local name="$1"
    local version="$2"
    local url="$3"
    local file="$CHARTS_DIR/${name}-${version}.tgz"

    if [ -f "$file" ]; then
        echo "[SKIP] $name $version — 已存在 ($(du -h "$file" | cut -f1))"
        return
    fi

    # GitHub URL 才加 MIRROR_BASE，非 GitHub URL（如 charts.jetstack.io）直连
    local full_url
    if echo "$url" | grep -q '^https://github\.com'; then
        full_url="${MIRROR_BASE:+"${MIRROR_BASE}/"}${url}"
    else
        full_url="$url"
    fi
    echo "[DL]   $name $version"
    echo "       ${full_url}"
    curl -fsSL "$full_url" -o "$file" --connect-timeout 30 --retry 3
    local size
    size=$(du -h "$file" | cut -f1)
    echo "[OK]   $name $version → $(basename "$file") (${size})"
}

echo "=============================================="
echo "  下载 Helm Charts"
echo "  Mirror: ${MIRROR_BASE:-直连 (无镜像)}"
echo "  保存到: ${CHARTS_DIR}"
echo "=============================================="
echo ""

# Cilium
download_chart "cilium" "1.18.11" \
    "https://github.com/cilium/charts/raw/master/cilium-1.18.11.tgz"

# MetalLB (chart 发布在 metallb-chart-* tag 下，不是 v* tag)
download_chart "metallb" "0.16.1" \
    "https://github.com/metallb/metallb/releases/download/metallb-chart-0.16.1/metallb-0.16.1.tgz"

# ingress-nginx
download_chart "ingress-nginx" "4.15.1" \
    "https://github.com/kubernetes/ingress-nginx/releases/download/helm-chart-4.15.1/ingress-nginx-4.15.1.tgz"

# cert-manager (chart 发布在 charts.jetstack.io，不是 GitHub Release)
download_chart "cert-manager" "v1.19.6" \
    "https://charts.jetstack.io/charts/cert-manager-v1.19.6.tgz"

# nfs-subdir-external-provisioner
download_chart "nfs-subdir-external-provisioner" "4.0.18" \
    "https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner/releases/download/nfs-subdir-external-provisioner-4.0.18/nfs-subdir-external-provisioner-4.0.18.tgz"

# Longhorn
download_chart "longhorn" "1.12.0" \
    "https://github.com/longhorn/charts/releases/download/longhorn-1.12.0/longhorn-1.12.0.tgz"

echo ""
echo "=============================================="
count=$(find "$CHARTS_DIR" -name '*.tgz' 2>/dev/null | wc -l | tr -d ' ')
echo "  全部完成，共 ${count} 个 chart"
echo "  目录: ${CHARTS_DIR}/"
echo "=============================================="
echo ""
echo "  提交到仓库:"
echo "    git add bootstrap/charts/"
echo "    git commit -m 'chore(bootstrap): add helm chart tarballs'"
echo ""
echo "  在集群节点上:"
echo "    git pull  # 或 scp 整个 charts/ 目录到对应路径"
echo "    bash bootstrap/install.sh"
echo ""
