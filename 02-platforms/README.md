# Platforms - 平台层

## 📂 目录结构

```
platforms/
├── docker/              # Docker 平台
├── k3s/                 # K3s Kubernetes 平台
└── install-components.sh  # 高频组件快速安装脚本 ✨
```

## 🚀 高频组件快速安装

### 方法 1：交互式菜单（推荐）
```bash
cd 02-platforms
./install-components.sh
```

### 方法 2：直接进入对应目录
```bash
# ingress-nginx
cd 03-infra-k8s/ingress-nginx/dev
./install.sh

# MetalLB
cd 03-infra-k8s/metallb/dev
./install.sh

# demo-go-tiny
cd 04-apps-k8s/demo-go-tiny/dev
./install.sh
```

## 📖 平台说明

| 平台 | 说明 |
|------|------|
| [docker/](./docker/) | Docker 平台 |
| [k3s/](./k3s/) | K3s Kubernetes 平台（推荐） |
