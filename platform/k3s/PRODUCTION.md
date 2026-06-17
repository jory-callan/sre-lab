# K3s 生产级部署指南

## 概述
本指南基于 NewVersion.md 整理，用于 3 节点 K3s HA 集群的生产部署。

## 环境要求
- 3 台 4C16G200G 服务器
- Rocky Linux 9.7 或类似系统
- 独立数据盘挂载到 /data

## 部署架构
```
1. Namespace 隔离：每个项目 test-* / prod-*
2. 存储策略：
   - 代码：hostPath 模式（/data/deploy/）
   - 日志/文件缓存：emptyDir 模式
3. Ingress：ingress-nginx 负责 vhost 转发
4. 证书：cert-manager 负责自动续签
```

## 部署步骤

### 1. 系统初始化
```bash
swapoff -a
sed -i '/swap/d' /etc/fstab
echo 1 > /proc/sys/net/ipv4/ip_forward
systemctl enable --now chronyd
```

### 2. 配置 100 年证书（可选）
```bash
mkdir -p ./k3s-100y-cert
cd ./k3s-100y-cert

curl -O https://raw.githubusercontent.com/k3s-io/k3s/refs/heads/main/contrib/util/generate-custom-ca-certs.sh
sed -i "s|-days 7300|-days 37000|g" ./generate-custom-ca-certs.sh
chmod +x ./generate-custom-ca-certs.sh

DATA_DIR=/data/k3s_data bash ./generate-custom-ca-certs.sh -
```

### 3. 配置镜像源
```bash
mkdir -p /etc/rancher/k3s
cat > /etc/rancher/k3s/registries.yaml <<EOF
mirrors:
  docker.io:
    endpoint:
      - "https://docker.m.daocloud.io"
      - "https://hub.atomgit.com"
      - "https://docker.1panel.live"
      - "https://docker.1ms.run"
  gcr.io:
    endpoint:
      - "gcr.nju.edu.cn"
      - "m.daocloud.io/gcr.io"
  ghcr.io:
    endpoint:
      - "ghcr.nju.edu.cn"
      - "m.daocloud.io/ghcr.io"
  k8s.gcr.io:
    endpoint:
      - "gcr.nju.edu.cn"
      - "m.daocloud.io/k8s.gcr.io"
      - "registry.cn-hangzhou.aliyuncs.com"
  registry.k8s.io:
    endpoint:
      - "k8s.nju.edu.cn"
config:
  docker.io:
    tls:
      insecure_skip_verify: true
EOF
```

### 4. Server 节点配置
```yaml
# /etc/rancher/k3s/config.yaml
data-dir: /data/k3s_data
default-local-storage-path: /data/k3s_data/local
token: "your-token-here"
tls-san:
  - "192.168.5.249"
  - "192.168.5.101"
  - "192.168.5.100"
disable:
  - traefik
  - servicelb
etcd-snapshot-retention: 30
etcd-snapshot-schedule-cron: "0 */8 * * *"
kube-controller-manager-arg:
  - "terminated-pod-gc-threshold=10"
  - "cluster-signing-duration=876000h"
kubelet-arg:
  - "container-log-max-files=3"
  - "container-log-max-size=10Mi"
  - "serialize-image-pulls=false"
  - "image-pull-progress-deadline=600s"
  - "image-gc-high-threshold=80"
  - "image-gc-low-threshold=70"
  - "eviction-hard=nodefs.available<15%,imagefs.available<15%"
  - "system-reserved=cpu=500m,memory=1Gi,ephemeral-storage=5Gi"
  - "kube-reserved=cpu=500m,memory=1Gi,ephemeral-storage=5Gi"
protect-kernel-defaults: true
secrets-encryption: true
```

### 5. 安装 Server 节点
```bash
echo 'CATTLE_NEW_SIGNED_CERT_EXPIRATION_DAYS=36500' > /etc/systemd/system/k3s.service.env

INSTALL_K3S_VERSION="v1.32.11-k3s1" \
curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | \
  INSTALL_K3S_MIRROR=cn \
  INSTALL_K3S_SKIP_SELINUX_RPM=true \
  sh -s - server \
  --docker \
  --cluster-init \
  --system-default-registry=registry.cn-hangzhou.aliyuncs.com
```

### 6. Agent 节点加入
```bash
INSTALL_K3S_VERSION="v1.32.11-k3s1" \
curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | \
  INSTALL_K3S_MIRROR=cn \
  K3S_URL=https://192.168.5.249:6443 \
  K3S_TOKEN=your-token-here \
  INSTALL_K3S_SKIP_SELINUX_RPM=true \
  sh -s - agent --docker
```

## 后续组件部署
1. **ingress-nginx**：已部署（参考 deploy-log-20260530）
2. **MetalLB**：参考 03-infra-k8s/metallb/
3. **cert-manager**：待部署
4. **demo-go-tiny**：参考 04-apps-k8s/demo-go-tiny/
