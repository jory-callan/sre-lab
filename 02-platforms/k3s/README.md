# K3s 部署指南

## 📂 目录结构

```
k3s/
├── README.md                # 本文档
├── PRODUCTION.md            # 生产级部署指南
├── QUICKSTART.md            # 快速开始
├── CHEATSHEET.md            # 命令速查
├── deploy-log-20260530/     # 2026-05-30 实际部署记录
├── examples/                # 配置示例
├── install-k3s.sh           # 安装脚本
├── uninstall-k3s.sh         # 卸载脚本
├── config.yaml              # 配置模板
├── registries.yaml          # 镜像源配置
└── archive/                 # 旧文件归档
```

## 🚀 快速开始 - 高频组件快速安装

### ingress-nginx
```bash
cd 03-infra-k8s/ingress-nginx/dev
./install.sh
```

### MetalLB
```bash
cd 03-infra-k8s/metallb/dev
./install.sh
```

### demo-go-tiny（测试真实客户端 IP）
```bash
cd 04-apps-k8s/demo-go-tiny/dev
./install.sh
```

## 📖 文档说明

| 文档 | 说明 |
|------|------|
| [PRODUCTION.md](./PRODUCTION.md) | 生产级部署指南 |
| [QUICKSTART.md](./QUICKSTART.md) | 快速开始 |
| [CHEATSHEET.md](./CHEATSHEET.md) | 命令速查 |
| [deploy-log-20260530/](./deploy-log-20260530/) | 2026-05-30 实际部署记录 |

## 🎯 你的集群当前状态

✅ **已安装：**
- ingress-nginx
- MetalLB
- demo-go-tiny

## 🧪 验证安装

### 测试 demo-go-tiny
```bash
# 修改 hosts
192.168.5.240 demo-go-tiny.czw-sre.internal

# 访问测试
curl http://demo-go-tiny.czw-sre.internal
```

### 检查服务
```bash
# ingress-nginx
kubectl get pods -n ingress-nginx

# MetalLB
kubectl get pods -n metallb-system
kubectl get ipaddresspools -n metallb-system

# demo-go-tiny
kubectl get pods,svc,ingress -l app=demo-go-tiny
```
