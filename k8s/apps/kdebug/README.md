# demo-go-tiny

## 快速开始
```bash
./install.sh
```

## 验证
```bash
kubectl get pods -l app=demo-go-tiny
kubectl get svc demo-go-tiny
kubectl get ingress demo-go-tiny
```

## 测试
修改本地 hosts 文件：
```
192.168.5.240 demo-go-tiny.czw-sre.internal
```

然后访问：
```bash
curl http://demo-go-tiny.czw-sre.internal/ip
```

## 卸载
```bash
./uninstall.sh
```
