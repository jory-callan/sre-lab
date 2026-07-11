# Bootstrap — 集群基础设施安装

Ansible 完成 OS 层配置和 k3s 安装后，通过本目录的脚本安装集群基础设施组件。

## 架构位置

```
infra-base/                    ← IaC: OS + k3s (Ansible)
├── bootstrap/                 ← ← 你在这里: 集群基础设施安装
│   ├── download-charts.sh     ← 下载所有 Helm chart 到本地
│   ├── charts/                ← 本地 Helm chart 缓存 (可提交到仓库)
│   ├── install.sh             ← 一键入口
│   ├── cilium/                ← CNI 网络层 (P0)
│   ├── metallb/               ← LoadBalancer (P1)
│   ├── ingress-nginx/         ← Ingress Controller (P1)
│   ├── cert-manager/          ← TLS 证书自动签发 (P1)
│   ├── nfs-storageclass/      ← 共享存储 (P2)
│   ├── longhorn/              ← 高可用块存储 (P2)
│   └── argocd/                ← GitOps 入口

gitops-manifests/              ← GitOps: 所有 K8s 组件通过 ArgoCD 管理
```

## 依赖关系

```
Cilium ── 网络基础
  │
  ├── MetalLB ── LoadBalancer IP
  │     │
  │     ├── ingress-nginx ── HTTP 入口
  │     │     │
  │     │     └── cert-manager ── TLS 证书
  │     │
  │     └── NFS StorageClass ── 共享存储
  │
  ├── Longhorn ── 高可用块存储 (副本/快照/备份)
  │
  └── ArgoCD ── GitOps 引擎
```

## 使用方式

### 1. 下载 Helm Charts（本地开发机执行）

```bash
# 默认使用 gh-proxy.com 镜像加速
bash bootstrap/download-charts.sh

# 如果镜像站失效，可切换其他镜像
MIRROR_BASE="https://your-mirror.example.com" bash bootstrap/download-charts.sh

# 或直连 GitHub（不推荐，国内网络不稳定）
MIRROR_BASE="" bash bootstrap/download-charts.sh
```

下载完成后，`charts/` 目录包含所有 `.tgz` 文件。建议提交到仓库：

```bash
git add bootstrap/charts/
git commit -m "chore(bootstrap): add helm chart tarballs"
```

### 2. 在集群控制节点上安装

```bash
# 方式 A: 通过 git pull 同步（推荐）
git pull
bash bootstrap/install.sh

# 方式 B: 单独拷贝 charts/ 目录到节点
scp -r bootstrap/charts/ root@k3s-server-1:/root/bootstrap/
ssh root@k3s-server-1 "bash /root/bootstrap/install.sh"

# 或单独安装某个组件
bash bootstrap/install.sh cilium
bash bootstrap/install.sh metallb
```

### 3. 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `MIRROR_BASE` | `https://gh-proxy.com` | GitHub 镜像加速地址。设为空字符串则直连 |
| `K3S_DATA_DIR` | `/opt/k3s_data` | k3s 数据目录（仅 Longhorn 使用） |

## 前置条件

- k3s 集群已安装，`flannel-backend: none`
- `helm` 和 `kubectl` 在控制节点可用（已由 k3s role 安装）
- 离线安装：先执行 `download-charts.sh` 并将 `charts/` 目录同步到控制节点
- **NFS 存储需要**：所有节点预加载 `nfs` + `nfsd` 内核模块（已集成在 `ansible/roles/linux-init/tasks/kernel.yml` 中，执行 `linux-init` 即可自动完成）

## 组件清单

| 组件 | 版本 | 命名空间 | 说明 | 优先级 |
|------|------|----------|------|--------|
| Cilium | 1.18.11 | kube-system | eBPF CNI + Hubble 网络可视化 | P0 - 网络基础 |
| MetalLB | 0.16.1 | metallb-system | 裸机 LoadBalancer（L2 模式） | P1 - 服务暴露 |
| ingress-nginx | 4.15.1 | ingress-nginx | Ingress Controller（LoadBalancer 模式） | P1 - HTTP 入口 |
| cert-manager | v1.19.6 | cert-manager | TLS 证书自动签发 & 续期 | P1 - HTTPS |
| NFS StorageClass | 4.0.18 | nfs-storageclass | 动态 NFS 卷供给（ReadWriteMany） | P2 - 共享存储 |
| Longhorn | 1.12.0 | longhorn-system | 高可用分布式块存储（副本/快照/备份） | P2 - 块存储 |

## 每个组件的 README 包含

- **架构图** — 组件在集群中的位置和交互
- **前置条件** — 什么必须先安装好
- **部署方式** — 命令行操作步骤
- **配置说明** — 关键参数和默认值
- **验证步骤** — 如何确认安装成功
- **清理方法** — 完整卸载步骤
- **注意事项** — 常见坑和实践建议
- **故障排查** — 常见问题根因和解决方案

## 设计原则

1. **轻量优先** — 每个组件只做一件事，做好
2. **国内友好** — 全部使用阿里云镜像或 gh-proxy.com 加速
3. **可卸载** — 每个组件都提供完整的清理步骤
4. **自包含** — NFS 服务器跑在集群内部，无需外部依赖
5. **离线优先** — 通过 `download-charts.sh` + `charts/` 目录实现零网络依赖安装
6. **GitOps 就绪** — 后续所有组件通过 ArgoCD 管理，bootstrap 只安装"先于 GitOps 存在"的根基组件
