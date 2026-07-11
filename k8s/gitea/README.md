# Gitea — 自托管 Git 服务

轻量级自托管 Git 服务，SQLite + NFS 持久化，ingress-nginx 域名访问。

| 项目 | 值 |
|------|-----|
| 版本 | [1.26.4](https://github.com/go-gitea/gitea) |
| Helm Chart | [gitea-charts/gitea](https://dl.gitea.com/charts/) |
| 命名空间 | `gitea` |
| 域名 | `gitea.czw-sre.internal` |
| 默认管理员 | `admin / admin123` |

## 部署

```bash
bash install.sh
```

> 前置条件：ingress-nginx + MetalLB + NFS StorageClass。

## 目录

| 路径 | 说明 |
|------|------|
| `values.yaml` | Helm values（管理员预配置、存储、Ingress） |
| `resourcequota.yaml` | 命名空间配额 |
| `DELIVERY.md` | 交付详情（架构、存储、SSH、运维） |

## 访问

| 方式 | 地址 |
|------|------|
| Web | `https://gitea.czw-sre.internal` |
| Git (HTTP) | `https://gitea.czw-sre.internal/<user>/<repo>.git` |
| Git (SSH) | `ssh://git@192.168.5.205:30022/<user>/<repo>.git` |
| 指标 | `https://gitea.czw-sre.internal/metrics` |

## 验证

```bash
kubectl -n gitea get pods
curl -s https://gitea.czw-sre.internal/api/healthz
# {"status":"pass"}
```
