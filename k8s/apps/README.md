# Apps — 自托管应用

集群底座（bootstrap/）部署完成后，通过本目录安装自托管应用。

## 架构位置

```
bootstrap/                    ← 集群底座（Cilium / MetalLB / ingress-nginx / NFS）
apps/                         ← ← 你在这里: 自托管应用
├── gitea/                    ← Git 仓库
├── argocd/                   ← GitOps 引擎
└── ...
```

## NodePort 端口规范

k3s NodePort 范围 `30000-32767`，按应用层划分：

| 范围 | 层级 | 说明 |
|------|------|------|
| **30080/30443** | ingress-nginx（特殊） | 唯一外网入口，固定端口 |
| **301xx** | Infrastructure | 基础设施组件 |
| **302xx** | Middleware | 中间件 |
| **303xx** | Application | 业务应用 |

## 部署

```bash
# 安装所有应用
bash apps/install.sh

# 单独安装
bash apps/install.sh gitea
bash apps/install.sh argocd
```

## 组件清单

| 组件 | 版本 | 命名空间 | 说明 |
|------|------|----------|------|
| Gitea | 1.26.4 | gitea | 自托管 Git 服务（SQLite + NFS + ingress） |
| ArgoCD | 7.8.2 | argocd | GitOps 入口（最小化安装，ClusterIP） |
| Kite | 0.12.3 | kite | K8s Web UI 管理面板（SQLite + NFS + ingress） |

## 前置条件

- [x] Cilium / MetalLB / ingress-nginx / NFS 等底座已就绪
- [x] `*.czw-sre.internal` DNS 指向 `192.168.5.205`
- [x] kubectl / helm 可用
