# Kite

## 快速开始

### 方式一：Manifests（默认）
```bash
# 安装
./install.sh

# 卸载
./uninstall.sh
```

### 方式二：Helm
```bash
# 安装
./install.sh helm

# 卸载
./uninstall.sh helm
```

### 配置 hosts（本地访问）
在 /etc/hosts 添加：
```
192.168.5.240 kite.czw-sre.internal
```

### 访问
浏览器打开：http://kite.czw-sre.internal

## 验证
```bash
kubectl get pods -n kite
kubectl get ingress -n kite
```

## 持久化
数据存储在 PVC 中，卸载时默认保留。
