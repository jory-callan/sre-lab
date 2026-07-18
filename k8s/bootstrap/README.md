# Bootstrap — 集群基础设施安装

Ansible 完成 OS 层配置和 k3s 安装后，通过本目录的脚本安装集群基础设施组件。

## 架构位置

```
infra-base/                    ← IaC: OS + k3s (Ansible)
├── bootstrap/                 ← ← 你在这里: 集群基础设施安装
│   ├── install.sh             ← 一键入口（调用各组件自己的 install.sh）
│   ├── cilium/                ← CNI 网络层 (P0)，自包含 chart
│   ├── metallb/               ← LoadBalancer (P1)，自包含 chart
│   ├── ingress-nginx/         ← Ingress Controller (P1)，自包含 chart
│   ├── cert-manager/          ← TLS 证书自动签发 (P1)，自包含 chart
│   ├── nfs-storageclass/      ← 共享存储 (P2)，自包含 chart
│   └── longhorn/              ← 高可用块存储 (P2)，自包含 chart

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
```

## 使用方式

### 节点管理

控制平面节点默认允许普通 Pod 调度。如需阻止普通 Pod 调度到控制平面节点（仅允许 DaemonSet），执行：

```bash
bash bootstrap/taint-control-plane.sh
```

此操作为控制平面节点添加 `node-role.kubernetes.io/control-plane:NoSchedule` 污点。
DaemonSet 默认可容忍此污点（如 Cilium、MetalLB），不受影响。

### 安装

```bash
# 安装所有组件（按依赖顺序）
bash bootstrap/install.sh

# 或单独安装某个组件（每个组件自包含 chart，无需提前下载）
bash bootstrap/install.sh cilium
bash bootstrap/install.sh metallb
```

每个组件目录自包含 Helm chart `.tgz`，安装脚本会自动使用本地 chart。如需离线同步，直接拷贝整个组件目录到目标节点即可。

### 3. 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `MIRROR_BASE` | `https://gh-proxy.com` | GitHub 镜像加速地址。设为空字符串则直连 |
| `K3S_DATA_DIR` | `/opt/k3s_data` | k3s 数据目录（仅 Longhorn 使用） |

## 前置条件

- k3s 集群已安装，`flannel-backend: none`
- `helm` 和 `kubectl` 在控制节点可用（已由 k3s role 安装）
- 每个组件目录自包含 Helm chart `.tgz`，直接拷贝组件目录到目标节点即可离线安装
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
6. **离线优先** — 每个组件自包含 Helm chart，无需网络依赖
