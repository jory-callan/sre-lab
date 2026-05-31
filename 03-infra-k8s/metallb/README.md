# MetalLB

## 快速开始
```bash
./install.sh
```

## 验证
```bash
kubectl get pods -n metallb-system
kubectl get ipaddresspools -n metallb-system
```

## 卸载
```bash
./uninstall.sh
```

## 说明
- 原始远程资源：https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml
- IP 地址池：192.168.5.240-192.168.5.250
- 高级配置请查看：高级配置指南.md
