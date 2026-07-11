# 集群规范

# Architecture

## 网络拓扑

```
macOS (开发/管理机 / Ansible)
        │ SSH
        ▼
┌───────────────┬───────────────┬───────────────┐
│ k3s-server-1  │ k3s-server-2  │ k3s-server-3  │
│ 192.168.5.249 │ 192.168.5.101 │ 192.168.5.109 │
│ server        │ server        │ server        │
│ 2C 8G 40G     │ 2C 8G 40G     │ 2C 8G 40G     │
└───────────────┴───────────────┴───────────────┘
```

由 macos 的 kubectl helm 操作集群，不要直接进服务器

## 节点规格

| 节点 | IP | 角色 | 规格 |
|------|----|------|------|
| k3s-server-1 | 192.168.5.249 | server | 2C 8G 40G |
| k3s-server-2 | 192.168.5.101 | server | 2C 8G 40G |
| k3s-server-3 | 192.168.5.109 | server | 2C 8G 40G |

## 网络规划

- 域名: *.czw-sre.internal → k3s-server-1 (路由/DNS 层)
- Pod CIDR: 10.42.0.0/16
- Service CIDR: 10.43.0.0/16
- 镜像源: 192.168.5.103:5000~5006 (本地 registry mirror)

## NodePort 端口规划

k3s 默认 NodePort 范围 `30000-32767`。

### 已分配

| 端口 | 组件 | 说明 |
|------|------|------|
| 30080 | ingress-nginx HTTP | 外网 HTTP 入口 |
| 30443 | ingress-nginx HTTPS | 外网 HTTPS 入口 |
| 30301 | Kite | K8s Web UI 管理面板 |
| 30777 | Longhorn UI | 分布式存储管理面板 |

> ingress-nginx 使用 30080/30443 而非 301xx，是因为它是集群唯一的外网入口，固定端口方便在路由器/firewall 上配置端口转发和 ACL。

---

## 域名规划

所有集群服务使用 `*.czw-sre.internal` 泛域名。

| 域名 | 服务 | 说明 |
|------|------|------|
| `gitea.czw-sre.internal` | Gitea | Git 仓库 |
| `argocd.czw-sre.internal` | ArgoCD | GitOps 引擎 |
| `kite.czw-sre.internal` | Kite | K8s Web UI |
| `longhorn.czw-sre.internal` | Longhorn | 分布式存储管理面板 |
| `*.czw-sre.internal` | 预留 | 后续服务按 `服务名.czw-sre.internal` 命名 |

**DNS 解析：** 路由器上配置 `*.czw-sre.internal A 192.168.5.205`（指向 ingress-nginx 的 MetalLB IP）。

---

## 命名规范

### 资源命名

| 资源 | 规范 | 示例 |
|------|------|------|
| Namespace | 小写字母，无特殊字符 | `gitea`, `argocd`, `ingress-nginx` |
| Deployment | 与服务名一致 | `gitea`, `argocd-server` |
| Service | 与服务名一致 | `gitea-http`, `gitea-ssh` |
| Ingress | `{服务名}` | `gitea`, `argocd-server` |
| PVC | `{组件名}-{用途}` | `gitea-shared-storage`, `nfs-server-data` |
| ConfigMap | `{组件名}-config` | `gitea-config` |

### Git 提交信息

```
<type>(<scope>): <subject>
```

**type:** `feat` / `fix` / `docs` / `refactor` / `chore`  
**scope:** 受影响的模块（如 `gitea`, `argocd`, `ingress-nginx`）  

示例：
```
feat(gitea): add Gitea 1.26.4 with NFS storage and ingress
fix(inventory): correct k3s data dir path
refactor: split bootstrap (foundation) and apps (self-hosted)
```

---

## 部署原则

1. **Ansible 层** — 只负责 OS 配置和 k3s 安装。所有 K8s 内部组件的安装通过 Helm 完成。
2. **bootstrap/** — 只放"先于 GitOps 存在"的集群底座组件（没有它们集群不可用）。
3. **apps/** — 自托管应用，通过 Helm install 部署。后续通过 ArgoCD 迁移到 GitOps 管理。
4. **幂等性** — 所有 install.sh 必须支持重复执行（已安装则跳过）。
5. **国内网络友好** — GitHub 资源使用 gh-proxy.com 前缀，镜像优先使用阿里云或私有 registry。

---

## 客户端 IP 保留

三层配置确保真实客户端 IP 不被 SNAT 隐藏：

1. **MetalLB + Service** → `externalTrafficPolicy: Local` → 保留源 IP 进入 ingress-nginx
2. **ingress-nginx** → `compute-full-forwarded-for: true` + `use-forwarded-headers: true` → 在 HTTP 头中传递
3. **后端应用（如 Gitea）** → 配置信任代理头 → 日志和审计记录真实来源

---

## 安全基线

- SELinux: disabled（k3s 要求）
- firewalld: disabled（k3s 管理 iptables/nftables）
- Swap: off（k3s 要求）
- k3s secrets-encryption: true（etcd 加密）
- k3s write-kubeconfig-mode: 600（仅 root 可读）
- k3s protect-kernel-defaults: true（内核参数保护）
