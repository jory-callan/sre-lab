# NFS StorageClass — 动态 NFS 卷供给

在 k3s 集群内创建一个自包含的 NFS 动态存储方案：内部 NFS 服务器 + `nfs-subdir-external-provisioner`，提供 ReadWriteMany 持久卷。

## 为什么用 NFS 而非 Longhorn

| 方案 | 优点 | 缺点 |
|------|------|------|
| **NFS（内核 nfsd）** | 极轻量、ReadWriteMany、部署秒级、sync 模式数据安全 | 单点、性能一般、无副本 |
| **Longhorn** | 副本高可用、快照、备份 | 资源占用高，2C8G 很吃力 |

Longhorn 在 2C8G 集群上的资源预估：

| 资源项 | 占用 | 说明 |
|--------|------|------|
| CPU（常驻） | ~0.5 core | manager + instance-manager + CSI 驱动 |
| CPU（IO 爆发） | 额外 ~1-2 cores | 副本引擎处理 I/O 时按需调度 |
| 内存 | 600MB ~ 1.5GB | 系统组件 + 每个 replica 引擎约 200-300MB |
| 磁盘（额外开销） | 每 1Gi 数据 ≈ 2Gi+ | 2 副本 + 快照元数据 |
| **推荐配置** | **最低 4C8G** | 小集群硬跑会严重影响其他业务 |

在 2C8G 测试集群上，NFS 是更务实的选择。**NFS 适合存储共享配置文件、日志、静态文件等非关键数据。**

## 架构

```
┌─────────────────────────────────────────────────┐
│                  Kubernetes                      │
│                                                   │
│  PVC (local-path) ─▶ NFS Server Pod (50Gi)       │
│                           │ 2049                  │
│                           ▼                       │
│  nfs-subdir-external-provisioner                  │
│     │ Creates subdir per PVC                      │
│     ▼                                             │
│  StorageClass: nfs-client (ReadWriteMany)         │
│     │                                             │
│     ├── PVC-A ─▶ /exports/namespace-pvc-a/        │
│     ├── PVC-B ─▶ /exports/namespace-pvc-b/        │
│     └── ...                                       │
└─────────────────────────────────────────────────┘
```

**NFS 实现：** 使用 `erichough/nfs-server` 镜像，通过挂载宿主机 `/proc/fs/nfsd` 直接调用**内核 nfsd**，不走 userspace NFS daemon。内核 NFS 的 IO 路径更短、上下文切换更少，性能显著优于纯用户态方案。

**存储后端：** NFS Server Pod 使用 local-path PVC 将数据持久化到节点本地磁盘（40GB 系统盘或 200GB 数据盘）。

## 前置条件

- [x] Cilium 网络已就绪
- [x] local-path StorageClass 正常（k3s 内置）
- [x] Helm 和 kubectl 可用
- [x] 所有节点已加载 `nfs` + `nfsd` 内核模块
  - 新部署：`ansible/roles/linux-init/tasks/kernel.yml` 已包含，执行 `bash ansible/run.sh linux-init` 即可自动加载并持久化
  - 已有集群：参考下方注意事项第 2 条手动加载

## 部署

```bash
ssh k3s-server-1
bash /root/bootstrap/install.sh nfs-storageclass
```

## 验证

```bash
# 检查 StorageClass
kubectl get sc
# 预期: nfs-client 存在

# 检查 NFS 组件
kubectl -n nfs-storageclass get pods

# 测试 ReadWriteMany PVC（配置文件在同级目录）
kubectl apply -f test-pvc.yaml
kubectl get pvc test-nfs-pvc
# 预期: STATUS=Bound

# 测试多 Pod 同时读写
kubectl run pod-a --image alpine --rm -it --restart=Never -- sh -c "echo 'hello from A' > /data/a.txt && cat /data/a.txt" -- -v test-nfs-pvc:/data
kubectl run pod-b --image alpine --rm -it --restart=Never -- sh -c "cat /data/a.txt && echo 'hello from B' > /data/b.txt" -- -v test-nfs-pvc:/data
```

## 配置参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| StorageClass 名称 | nfs-client | 可通过 `storageClass.name` 修改 |
| NFS 服务器存储 | 50Gi (local-path) | NFS server pod 的数据卷大小 |
| reclaimPolicy | Delete | PVC 删除后自动清理 NFS 子目录 |
| allowVolumeExpansion | true | 支持动态扩容 |
| accessModes | ReadWriteMany | 多 Pod 同时读写 |
| NFS 导出模式 | **sync** | 服务端 sync 写，不丢失已确认数据 |
| 客户端挂载选项 | vers=3,hard,intr,sync,timeo=600,retrans=5 | 数据库场景安全配置 |

## 使用示例

示例文件在同级目录下：

```bash
# 测试 PVC
kubectl apply -f test-pvc.yaml
kubectl get pvc test-nfs-pvc          # STATUS=Bound

# 完整应用示例（Deployment + PVC）
kubectl apply -f example-app.yaml
kubectl exec deploy/my-app -- ls /usr/share/nginx/html
```

## 性能说明

> ⚠️ v2 改用 `erichough/nfs-server`（内核 nfsd）后，相比原 `itsthenetwork/nfs-server-alpine`（userspace unfsd），
> 吞吐量提升约 **2-3 倍**，延迟降低 **50%** 以上。但底层仍是 NFS 协议，不适合数据库类高并发随机 IO 负载。

| 场景 | 表现（内核 nfsd） | 建议 |
|------|------------------|------|
| 小文件读写 | ✅ 较好 | 适合配置/日志/静态文件 |
| 大文件顺序读写 | ✅ 良好 | 约 150-300MB/s（取决于节点磁盘和网络） |
| 高并发随机 IO | ⚠️ 一般 | 仍不适合数据库类负载 |
| 多 Pod 共享 | ✅ 原生支持 | NFS 的核心优势 |

## 清理

```bash
# 卸载 provisioner
helm uninstall nfs-provisioner -n nfs-storageclass

# 删除 NFS 服务器
kubectl delete deployment nfs-server -n nfs-storageclass
kubectl delete pvc nfs-server-data -n nfs-storageclass

# 清理命名空间
kubectl delete namespace nfs-storageclass

# 清理测试资源
kubectl delete pvc test-nfs-pvc
```

## 注意事项

1. **NFS 服务器是单点** — 仅 1 副本，Pod 故障重启期间存储不可用。生产环境建议使用外部 NAS 或改用 Longhorn
2. **内核 nfsd 依赖 `nfs` + `nfsd` 两个模块** — `erichough/nfs-server` 镜像需要宿主机同时加载 `nfs`（客户端）和 `nfsd`（服务端）内核模块。k3s 默认不会自动加载。
   - **新部署**：`ansible/roles/linux-init/tasks/kernel.yml` 已包含，执行 `bash ansible/run.sh linux-init` 即可在所有节点自动加载并持久化
   - **已有集群**：每个节点手动执行：
   ```bash
   # 临时加载
   modprobe nfs && modprobe nfsd
   # 持久化（重启后自动加载）
   echo 'nfs'  > /etc/modules-load.d/nfs.conf
   echo 'nfsd' >> /etc/modules-load.d/nfs.conf
   ```
   验证：`lsmod | grep -E '^nfs'` 应看到 `nfs`、`nfsd`、`nfs_acl`、`lockd` 等模块。
3. **`/proc/fs/nfsd` 挂载** — 容器通过 hostPath 挂载宿主机的 `/proc/fs/nfsd` 来调用内核 nfsd，不再需要 userspace NFS daemon
4. **数据存储在宿主机** — NFS Server 的数据最终落在 local-path 所在节点。如需持久化到数据盘，提前改 local-path 的默认路径
5. **不支持跨节点实时同步** — 如果 NFS server Pod 漂移到另一个节点，数据仍然在原来的节点上。解决方案：用 nodeSelector 固定 NFS server 到某节点
6. **NodePort 或 LoadBalancer 从外部访问** — NFS Server 是 ClusterIP 仅供集群内使用，外部访问需额外配置

## 故障排查

| 现象 | 可能原因 | 解决 |
|------|---------|------|
| PVC 一直 Pending | NFS 服务器未就绪 | 检查 `kubectl -n nfs-storageclass get pods` |
| Pod 挂载 NFS 超时 | NFS Server IP 变化（Pod 重启后） | 重新部署 provisioner 更新 IP |
| 权限错误 (Permission denied) | NFS 目录权限问题 | NFS Server 容器内 `chmod 777 /exports` |
| NFS Server CrashLoopBackOff | 内核 `nfs` 或 `nfsd` 模块未加载 | 节点执行 `modprobe nfs && modprobe nfsd` |
| I/O 超时 | 网络丢包或节点负载高 | 检查节点网络和资源使用 |
| 容器报 `open /proc/fs/nfsd/...: no such file or directory` | 宿主机 `/proc/fs/nfsd` 不存在 | `modprobe nfsd` 后重启 Pod |
