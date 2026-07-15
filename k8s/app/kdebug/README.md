# kdebug — K8s 调试工具

轻量级 HTTP 调试 Pod，用于验证集群网络、Ingress、证书、HPA 等基础设施。

| 项目 | 值 |
|------|-----|
| 版本 | [v1.0.2](https://github.com/jory-callan/kdebug) |
| Helm Chart | `helm-hosted/kdebug` (0.1.0) |
| 镜像 | `ghcr.io/jory-callan/kdebug:v1.0.2` |
| 命名空间 | `kdebug` |
| 域名 | `kdebug.czw-sre.internal` |
| NodePort | `30302` |

## 部署

```bash
# 1. 首次：打包 chart 并推送到本地 Nexus
bash download.sh

# 2. 安装
bash install.sh
```

## 目录

| 路径 | 说明 |
|------|------|
| `helm/` | Helm chart 源码 |
| `download.sh` | 打包 chart → 推送到本地 Nexus |
| `install.sh` | 从本地 Nexus 安装 |
| `uninstall.sh` | 卸载 + 命名空间清理 |
| `DELIVERY.md` | 交付详情（架构、端点、证书） |

## 验证

```bash
# Ingress HTTPS
curl -k https://kdebug.czw-sre.internal/ping
# {"code":0,"msg":"pong"}

# 内部 DNS
kubectl -n kdebug run test --image=busybox -it --rm -- wget -qO- kdebug.kdebug.svc.cluster.local/ping
```
