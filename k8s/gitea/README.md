# Gitea — 自托管 Git 服务

轻量级自托管 Git 服务，SQLite + NFS 持久化，ingress-nginx 域名访问。

| 项目 | 值 |
|------|-----|
| 版本 | [1.26.4](https://github.com/go-gitea/gitea) |
| Helm Chart | `helm-hosted/gitea` (12.6.0) |
| 命名空间 | `gitea` |
| 域名 | `gitea.czw-sre.internal` |
| 默认管理员 | `admin / Admin@czw123` |

## 部署

```bash
# 1. 首次：下载 chart 并推送到本地 Nexus
bash download.sh

# 2. 安装
bash install.sh
```

> Chart 从本地 Nexus（`http://192.168.5.103:8081/repository/helm-hosted/`）安装，不进入 git 仓库。

## 目录

| 路径 | 说明 |
|------|------|
| `download.sh` | 下载 chart → 推送到本地 Nexus |
| `values.yaml` | Helm values（管理员预配置、存储、Ingress） |
| `install.sh` | 从本地 Nexus 安装 |
| `uninstall.sh` | 卸载 + PVC 清理 |
| `resourcequota.yaml` | 命名空间配额 |
| `DELIVERY.md` | 交付详情（架构、存储、SSH、运维） |

## 访问

| 方式 | 地址 |
|------|------|
| Web | `https://gitea.czw-sre.internal` |
| Git (HTTP) | `https://gitea.czw-sre.internal/<user>/<repo>.git` |
| Git (SSH) | `ssh://git@<node-ip>:30022/<user>/<repo>.git` |
| NodePort HTTP | `<node-ip>:30021` |
| 指标 | `https://gitea.czw-sre.internal/metrics` |

## 验证

```bash
kubectl -n gitea get pods
curl -s https://gitea.czw-sre.internal/api/healthz
# {"status":"pass"}
```
