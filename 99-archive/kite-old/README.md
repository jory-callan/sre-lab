# Kite

## 快速开始

### 使用 manifests
```bash
kubectl apply -f manifests/install.yaml
```

### 使用 helm
```bash
helm install kite helm/
```

## 验证
```bash
kubectl get pods -l app=kite
```

## 卸载

### 使用 manifests
```bash
kubectl delete -f manifests/install.yaml
```

### 使用 helm
```bash
helm uninstall kite
```
