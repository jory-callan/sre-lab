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
#   - kubectl 优先尝试清华源，失败后自动 fallback 到官方源
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

download_file_with_fallback() {
  local output="$1"
  shift

  local url
  local tried_urls=""

  for url in "$@"; do
    tried_urls="${tried_urls}  - ${url}\n"
    echo "   尝试下载: $url"
    if curl -fsSL -o "$output" "$url"; then
      echo "   下载成功: $url"
      return 0
    fi
    echo "   下载失败，尝试下一个源"
  done

  echo "ERROR: 下载失败，已尝试以下地址:"
  printf "%b" "$tried_urls"
  return 1
}

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

  # 清华源优先；清华源未同步该版本时 fallback 到官方源。
  # 阿里云 kubernetes-release 镜像对较新 patch 版本经常缺失，放在最后兜底。
  local tmp_file
  tmp_file="$(mktemp /tmp/kubectl.XXXXXX)"

  if ! download_file_with_fallback "$tmp_file" \
    "https://mirrors.tuna.tsinghua.edu.cn/kubernetes/release/v${KUBECTL_VERSION}/bin/${OS}/${ARCH}/kubectl" \
    "https://mirrors.tuna.tsinghua.edu.cn/kubernetes-release/release/v${KUBECTL_VERSION}/bin/${OS}/${ARCH}/kubectl" \
    "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/${OS}/${ARCH}/kubectl" \
    "https://mirrors.aliyun.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/${OS}/${ARCH}/kubectl"; then
    rm -f "$tmp_file"
    exit 1
  fi

  install -m 0755 "$tmp_file" /usr/local/bin/kubectl
  rm -f "$tmp_file"

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