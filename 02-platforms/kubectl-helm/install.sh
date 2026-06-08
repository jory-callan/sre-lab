#!/bin/bash
set -e

# Kubectl + Helm 安装脚本
# 支持自定义版本，国内网络适配
#
# 用法:
#   # 默认版本（kubectl 1.31.13, helm 3.17.2）
#   bash install.sh
#
#   # 指定版本
#   KUBECTL_VERSION=1.32.0 HELM_VERSION=3.16.0 bash install.sh
#
#   # 覆盖已安装版本
#   FORCE=true KUBECTL_VERSION=1.31.13 HELM_VERSION=3.17.2 bash install.sh
#
# 说明:
#   - kubectl 从阿里云镜像下载（国内快）
#   - helm 从 GitHub releases 下载（经 gh-proxy.com 代理）
#   - 安装到 /usr/local/bin/

# ==============================================
# 配置（通过环境变量覆盖）
# ==============================================
KUBECTL_VERSION="${KUBECTL_VERSION:-1.31.13}"
HELM_VERSION="${HELM_VERSION:-3.17.2}"
ARCH="${ARCH:-amd64}"
OS="${OS:-linux}"
FORCE="${FORCE:-false}"

# ==============================================
# 安装 kubectl
# ==============================================
install_kubectl() {
  if command -v kubectl &> /dev/null && [ "$FORCE" != "true" ]; then
    local current_ver
    current_ver="$(kubectl version --client --short 2>/dev/null | sed 's/.*v//' || true)"
    echo "==> kubectl 已安装 (v$current_ver)，跳过。如要覆盖请先卸载。"
    return
  fi

  echo "==> 安装 kubectl v${KUBECTL_VERSION} (${OS}/${ARCH})"

  # 阿里云镜像（国内快），若需要可改为官方地址
  #  官方: https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/${OS}/${ARCH}/kubectl
  local url="https://mirrors.aliyun.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/${OS}/${ARCH}/kubectl"

  curl -fsSL -o /usr/local/bin/kubectl "$url"
  chmod +x /usr/local/bin/kubectl

  echo "   kubectl v${KUBECTL_VERSION} -> /usr/local/bin/kubectl"
}

# ==============================================
# 安装 helm
# ==============================================
install_helm() {
  if command -v helm &> /dev/null && [ "$FORCE" != "true" ]; then
    local current_ver
    current_ver="$(helm version --short 2>/dev/null | sed 's/.*v//;s/+.*//' || true)"
    echo "==> helm 已安装 (v$current_ver)，跳过。如要覆盖请先卸载。"
    return
  fi

  echo "==> 安装 helm v${HELM_VERSION} (${OS}/${ARCH})"

  local tarball="helm-v${HELM_VERSION}-${OS}-${ARCH}.tar.gz"
  local url="https://gh-proxy.com/https://github.com/helm/helm/releases/download/v${HELM_VERSION}/${tarball}"

  curl -fsSL "$url" | tar -xz -C /tmp "${OS}-${ARCH}/helm"
  mv "/tmp/${OS}-${ARCH}/helm" /usr/local/bin/helm
  rm -rf "/tmp/${OS}-${ARCH}"

  echo "   helm v${HELM_VERSION} -> /usr/local/bin/helm"
}

# ==============================================
# 验证
# ==============================================
verify() {
  echo ""
  echo "==> 验证"
  echo ""

  if command -v kubectl &> /dev/null; then
    echo "kubectl:"
    kubectl version --client --output=yaml 2>/dev/null || kubectl version --client 2>/dev/null || true
  else
    echo "kubectl: 未安装"
  fi

  echo ""
  if command -v helm &> /dev/null; then
    echo "helm:"
    helm version 2>/dev/null || true
  else
    echo "helm: 未安装"
  fi
}

# ==============================================
# 主流程
# ==============================================
echo "=== 安装 kubectl + helm ==="
echo ""

install_kubectl
install_helm
verify

echo ""
echo "安装完成。"