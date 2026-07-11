# Metrics Server

> 当前集群使用 k3s 内置的 metrics-server，不需要额外部署。
> 此目录保留 Helm 版配置供参考，如后续需要替换 k3s 内置版时可直接使用。

## 背景

k3s 默认内置 metrics-server，但版本跟随 k3s 更新，无法独立管理。
如果以后需要替换为 Helm 独立部署版，配置见本目录。

## 配置

| 文件 | 说明 |
|------|------|
| `kustomization.yaml` | Helm chart v3.13.1 / metrics-server 0.8.1 |
| `values.yaml` | `--kubelet-insecure-tls`（k3s 自签名 kubelet 证书必须） |
| `resourcequota.yaml` | 资源限制 |
| `application.yaml` | ArgoCD Application 定义（供参考） |

## 切换为 Helm 部署的操作步骤

```bash
# 1. 把所有文件移到正式目录
mkdir -p infrastructure/metrics-server argocd/metrics-server
cp lab/metrics-server/kustomization.yaml infrastructure/metrics-server/
cp lab/metrics-server/values.yaml infrastructure/metrics-server/
cp lab/metrics-server/resourcequota.yaml infrastructure/metrics-server/
cp lab/metrics-server/application.yaml argocd/metrics-server/

# 2. 在 k3s server 节点上禁用内置 metrics-server
echo '--disable=metrics-server' | sudo tee -a /etc/rancher/k3s/config.yaml
sudo systemctl restart k3s       # 单节点

# 3. 验证旧版消失
kubectl -n kube-system get pod -l k8s-app=metrics-server

# 4. ArgoCD 自动同步 Helm 版到 kube-system
kubectl -n kube-system get deployment metrics-server
kubectl top nodes
```
