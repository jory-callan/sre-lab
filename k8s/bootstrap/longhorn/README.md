# Longhorn — 高可用分布式块存储

Longhorn 是 Kubernetes 原生的分布式块存储系统，提供卷副本、快照、备份和恢复功能。  
**当前配置：** replicaCount=1，单副本测试模式，与 NFS StorageClass 共存。

## 为什么需要 Longhorn

| 对比 | NFS StorageClass（已有） | Longhorn（新增） |
|------|------------------------|-----------------|
| 访问模式 | ReadWriteMany | ReadWriteOnce（默认），RWX 通过 NFSv4 Share Manager |
| 数据副本 | 单点，无副本 | 可配置 1-3 副本 |
| 快照/备份 | 无 | ✅ 原生支持（周期性快照 + 远程备份到 S3/NFS） |
| 性能 | 中等（内核 nfsd，受网络瓶颈） | 高（本地 iSCSI 直连，读写本地盘） |
| 适用场景 | 配置文件、日志、静态文件共享 | 数据库、有状态应用、需要高性能的场景 |
| 资源占用 | 极轻量 | 较重（~1.5-2GB 常驻内存） |

## 架构

```
┌─────────────────────────────────────────────────────────┐
│                    Kubernetes 集群                        │
│                                                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │ Node 1   │  │ Node 2   │  │ Node 3   │              │
│  │ 200G 盘  │  │ 200G 盘  │  │ 200G 盘  │              │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘              │
│       │              │              │                    │
│  ┌────▼──────────────▼──────────────▼─────────────────┐ │
│  │              Longhorn Manager                       │ │
│  │  副本管理 / 卷调度 / 快照 / 备份 / 健康检测         │ │
│  └──────────────────────┬─────────────────────────────┘ │
│                         │                                │
│  ┌──────────────────────▼─────────────────────────────┐ │
│  │             Instance Manager                        │ │
│  │        V1/V2 Data Engine (iSCSI/NVMe)              │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │  CSI Driver → kubelet → Pod                        │ │
│  └────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## 前置条件

- [x] **Ansible linux-init** 已执行 — 包含 open-iscsi + iscsi_tcp 内核模块
- [x] Cilium 网络已就绪
- [x] kubectl 和 Helm 可用
- [ ] (可选) 节点有额外裸数据盘

## 部署

```bash
# 一键安装（默认 k3s_data_dir=/opt/k3s_data）
bash bootstrap/install.sh longhorn

# 如果 k3s data-dir 不同，需设置环境变量
export K3S_DATA_DIR=/path/to/k3s/data
bash bootstrap/longhorn/install.sh
```

### 存储盘配置（方法一：安装时挂载）

SSH 到目标节点，确认 200G 数据盘：

```bash
lsblk -dno NAME,SIZE | grep "200G"

# 格式化并挂载到 Longhorn 默认路径
sudo mkfs.ext4 /dev/sdb
sudo mkdir -p /var/lib/longhorn
sudo mount /dev/sdb /var/lib/longhorn
echo "/dev/sdb /var/lib/longhorn ext4 defaults 0 0" | sudo tee -a /etc/fstab

# 重启 longhorn-manager 识别新盘
kubectl -n longhorn-system delete pods -l app=longhorn-manager
```

### 存储盘配置（方法二：通过 UI 添加）

1. 访问 Longhorn UI（NodePort 或 Ingress）
2. Node → 选择节点 → Edit Node → Disks → Add Disk
3. 指定路径（可挂载盘上的子目录）
4. 保存

### Ingress 域名访问（可选）

安装脚本会自动部署 Ingress，如未部署可手动执行：

```bash
kubectl apply -f bootstrap/longhorn/ingress.yaml
# 访问: https://longhorn.czw-sre.internal
```

> 前置条件：ingress-nginx 已就绪，cert-manager ClusterIssuer 已配置。
> DNS 需要将 `longhorn.czw-sre.internal` 解析到 ingress-nginx 的 MetalLB IP。

## 验证

```bash
# 检查组件状态
kubectl -n longhorn-system get pods

# 检查 StorageClass
kubectl get sc
# 应看到 longhorn (非默认)

# 创建测试 PVC
kubectl apply -f bootstrap/longhorn/test-pvc.yaml
kubectl get pvc test-longhorn-pvc

# 查看卷
kubectl -n longhorn-system get volumes
```

## 配置说明

| 参数 | 默认值 | 说明 |
|------|--------|------|
| replicaCount | 1（当前） | 卷副本数，测试用 1，生产建议 2-3 |
| defaultStorageClass | false | Longhorn 不作为默认 StorageClass（避免影响现有工作负载） |
| csi.kubeletRootDir | /opt/k3s_data/agent/kubelet | k3s 的 kubelet socket 路径 |
| service.ui.type | NodePort | UI 服务类型 |
| service.ui.nodePort | 30777 | UI NodePort 端口 |
| defaultDataPath | /var/lib/longhorn | 节点默认存储路径 |

## 使用示例

### PVC 使用 Longhorn

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-longhorn-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn    # 指定 longhorn
  resources:
    requests:
      storage: 10Gi
```

### 扩容卷

```bash
kubectl patch pvc my-longhorn-pvc -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'
```

## 清理

```bash
# 卸载 Longhorn
helm uninstall longhorn -n longhorn-system
kubectl delete namespace longhorn-system

# 清理 CRD
kubectl get crd | grep longhorn | awk '{print $1}' | xargs kubectl delete crd

# 清理存储目录（在节点上执行）
sudo rm -rf /var/lib/longhorn/
```

## 注意事项

1. **replicaCount=1 仅用于测试** — 节点或磁盘故障会丢失数据，生产环境至少 2 副本
2. **磁盘规划** — Longhorn 的 `defaultDataPath` 默认在系统盘，建议挂载独立数据盘
3. **资源占用** — 2C8G 节点运行 Longhorn 约占用 0.5 core + 1.5-2GB 内存
4. **与 NFS 共存** — 两者 StorageClass 不同（`longhorn` vs `nfs-client`），PVC 指定即可
5. **K3S 兼容** — 必须通过 `csi.kubeletRootDir` 指定正确的 kubelet 路径，否则 CSI 驱动无法工作
6. **Longhorn UI** — 默认 NodePort 30777，也可通过端口转发访问

## 故障排查

| 现象 | 可能原因 | 解决 |
|------|---------|------|
| Pod 一直 ContainerCreating | CSI Driver 未就绪 | 检查 `kubectl -n longhorn-system get pods` 中的 `csi-*` 组件状态 |
| 卷一直 attaching | kubelet 路径不对 | 确认 `csi.kubeletRootDir` 与 k3s 实际 data-dir 一致 |
| 磁盘显示 "Unknown" 或 "Unscheduled" | 磁盘路径不可用或权限问题 | 检查节点上目标目录是否存在、可写 |
| 创建卷失败 | 磁盘空间不足 | `df -h /var/lib/longhorn/` 检查可用空间 |
| Manager CrashLoopBackOff | 节点资源不足 | `free -h` 检查内存，`kubectl describe pod` 查看具体原因 |
| UI 打不开 | NodePort 未暴露或防火墙屏蔽 | `kubectl -n longhorn-system get svc longhorn-frontend` 确认端口 |
