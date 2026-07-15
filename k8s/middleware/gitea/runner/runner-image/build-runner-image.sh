#!/bin/bash
# build-runner-image.sh - 在 K3s 节点上构建 runner-base 镜像并推送到 Nexus
# 用法: bash build-runner-image.sh
set -euo pipefail

NODE="root@192.168.5.107"
REGISTRY="192.168.5.103:5001"
IMAGE="${REGISTRY}/admin/runner-base"
TAG="latest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_DIR="/tmp/runner-base-build"

echo "==> 准备构建环境..."
ssh "${NODE}" "rm -rf ${REMOTE_DIR} && mkdir -p ${REMOTE_DIR}"

# 传输 Dockerfile
scp "${SCRIPT_DIR}/Dockerfile" "${NODE}:${REMOTE_DIR}/"

echo "==> 下载工具二进制到节点..."
ssh "${NODE}" bash -s <<'EOF'
set -euo pipefail
cd /tmp/runner-base-build

# Docker CLI
curl -sfL -o docker-cli "https://download.docker.com/linux/static/stable/x86_64/docker-29.6.1.tgz"
tar xzf docker-cli --strip-components=1 docker/docker
rm -f docker-cli

# kubectl
curl -sfL -o kubectl "https://dl.k8s.io/release/v1.31.0/bin/linux/amd64/kubectl"

# helm
curl -sfL -o helm.tar.gz "https://get.helm.sh/helm-v3.16.0-linux-amd64.tar.gz"
tar xzf helm.tar.gz --strip-components=1 linux-amd64/helm
rm -f helm.tar.gz

echo "==> 工具下载完成:"
ls -lh docker kubectl helm
EOF

echo "==> 构建镜像..."
ssh "${NODE}" "cd ${REMOTE_DIR} && docker build -t ${IMAGE}:${TAG} ."

echo "==> 登录 Nexus..."
ssh "${NODE}" "docker login ${REGISTRY} -u admin -p admin123 2>/dev/null"

echo "==> 推送到 Nexus..."
ssh "${NODE}" "docker push ${IMAGE}:${TAG}"

echo "==> 清理..."
ssh "${NODE}" "rm -rf ${REMOTE_DIR}"

echo ""
echo "✅ runner-base 镜像构建完成: ${IMAGE}:${TAG}"
