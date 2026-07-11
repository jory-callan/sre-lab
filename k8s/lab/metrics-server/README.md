# Metrics Server

> 当前集群使用 k3s 内置的 metrics-server，不需要额外部署。
> 此目录保留 Helm 版配置供参考。

## 配置

| 文件 | 说明 |
|------|------|
| `values.yaml` | `--kubelet-insecure-tls`（k3s 自签名 kubelet 证书必须） |
| `resourcequota.yaml` | 资源限制 |

## 切换为 Helm 部署的操作步骤

```bash
# 1. 在 k3s server 节点上禁用内置 metrics-server
echo '--disable=metrics-server' | sudo tee -a /etc/rancher/k3s/config.yaml
sudo systemctl restart k3s

# 2. 部署 Helm 版
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --values lab/metrics-server/values.yaml \
  --version 3.13.1

# 3. 验证
kubectl -n kube-system get deployment metrics-server
kubectl top nodes
```
