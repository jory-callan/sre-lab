# ingress-nginx

## 快速开始
```bash
./install.sh
```

## 验证
```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

## 卸载
```bash
./uninstall.sh
```

## 说明
- 原始远程资源：https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.0/deploy/static/provider/cloud/deploy.yaml
- 已配置真实客户端 IP 透传
- 高级配置请查看：高级配置指南.md
