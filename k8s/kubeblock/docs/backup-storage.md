# 备份存储后端切换指南

> 本文档说明如何将 KubeBlocks 的备份存储目标从 MinIO S3
> 切换到其他后端（NFS / FTP / AWS S3 / PVC / 阿里云 OSS 等）。

---

## 1. 基本原则

备份存储切换**不会影响已有的数据库实例**，也不需要重建 Cluster。
唯一需要操作的是 BackupRepo 资源。

切换步骤总是：

```
1. 创建新的 BackupRepo（或修改现有的）
2. 标记为新默认（is-default-repo: true）
3. 下次备份自动写入新的存储
4. 旧存储上的备份记录仍然可用（用于恢复）
```

---

## 2. 当前配置

```yaml
# BackupRepo: minio-backuprepo (当前默认)
spec:
  storageProviderRef: minio    # StorageProvider 名称
  accessMethod: Tool           # 工具模式（进程直传）
  config:
    bucket: kubeblocks-backup
    endpoint: http://minio.minio.svc:80
    insecure: "true"
  credential:
    name: minio-backuprepo-credential
    namespace: kb-system
```

---

## 3. 可用 StorageProvider

KubeBlocks 1.0.2 内建以下 StorageProvider（`kubectl get storageprovider`）：

| 名称 | 类型 | 当前状态 | accessMethod | 是否需要额外 CSI 驱动 |
|------|------|---------|-------------|-------------------|
| `minio` | S3 兼容 (MinIO) | ✅ Ready | Tool 或 Mount | ❌ 不需要 |
| `s3` | AWS S3 | ✅ Ready | Tool 或 Mount | ❌ 不需要 |
| `s3-compatible` | 通用 S3 (Ceph/等) | ✅ Ready | Tool 或 Mount | ❌ 不需要 |
| `ftp` | FTP 服务器 | ✅ Ready | Tool | ❌ 不需要 |
| `pvc` | Kubernetes PVC | ✅ Ready | Tool | ❌ 不需要 |
| `nfs` | NFS 共享存储 | ⚠️ NotReady | Mount | ✅ 需要 `nfs.csi.k8s.io` |
| `azureblob` | Azure Blob Storage | ✅ Ready | Tool | ❌ 不需要 |
| `oss` | 阿里云 OSS | ✅ Ready | Tool | ❌ 不需要 |
| `cos` | 腾讯云 COS | ⚠️ NotReady | Mount | ✅ 需要 `ru.yandex.s3.csi` |
| `obs` | 华为云 OBS | ⚠️ NotReady | Mount | ✅ 需要 `ru.yandex.s3.csi` |

> **状态说明**：
> - `Ready`：该 Provider 的定义完整，可以直接使用
> - `NotReady`：缺少 CSI 驱动（部分 Provider 的 Mount 模式需要 CSI 驱动，但 Tool 模式可能仍可用）
>
> **accessMethod 说明**：
> - `Tool`：备份 Pod 内的 datasafed 进程直接流式上传（**推荐**，不依赖 CSI）
> - `Mount`：通过 CSI 驱动将存储卷挂载到备份 Pod，写文件到挂载点（需要 CSI 驱动）

---

## 4. 各后端切换步骤

### 4.1 切换到 AWS S3

```bash
# 1. 创建凭证 Secret
kubectl create secret generic aws-s3-credential \
  -n kb-system \
  --from-literal=accessKeyId=AKIAXXXXXXXXXX \
  --from-literal=secretAccessKey=xxxxxxxxxxxx

# 2. 创建 BackupRepo
kubectl apply -f - <<EOF
apiVersion: dataprotection.kubeblocks.io/v1alpha1
kind: BackupRepo
metadata:
  name: aws-s3-backuprepo
  annotations:
    dataprotection.kubeblocks.io/is-default-repo: "true"
spec:
  storageProviderRef: s3
  accessMethod: Tool
  config:
    bucket: my-kubeblocks-backup
    region: us-west-2
  credential:
    name: aws-s3-credential
    namespace: kb-system
  pvReclaimPolicy: Retain
EOF

# 3. 验证
kubectl get backuprepo -w
```

### 4.2 切换到通用 S3 兼容（Ceph / 其他 MinIO 实例）

```yaml
# 使用 s3-compatible Provider（支持自定义 endpoint）
spec:
  storageProviderRef: s3-compatible
  accessMethod: Tool
  config:
    bucket: kubeblocks-backup
    endpoint: http://ceph-s3.ceph.svc:80
    region: us-east-1
    insecure: "true"
    forcePathStyle: "true"    # Ceph/MinIO 需要
    serviceProvider: "Other"  # rclone provider 名称
  credential:
    name: ceph-s3-credential
    namespace: kb-system
```

### 4.3 切换到 FTP

```bash
kubectl create secret generic ftp-credential \
  -n kb-system \
  --from-literal=accessKeyId=ftpuser \
  --from-literal=secretAccessKey=ftppassword

kubectl apply -f - <<EOF
apiVersion: dataprotection.kubeblocks.io/v1alpha1
kind: BackupRepo
metadata:
  name: ftp-backuprepo
  annotations:
    dataprotection.kubeblocks.io/is-default-repo: "true"
spec:
  storageProviderRef: ftp
  accessMethod: Tool
  config:
    bucket: /backups/kubeblocks    # FTP 路径
    endpoint: ftp://192.168.1.100:21
    insecure: "true"
  credential:
    name: ftp-credential
    namespace: kb-system
  pvReclaimPolicy: Retain
EOF
```

### 4.4 切换到 PVC（本地存储）

```yaml
# 注意：PVC 模式会创建一个 PV 绑定的 PVC 作为备份目标
# 备份数据写入 PVC，而不是对象存储
spec:
  storageProviderRef: pvc
  accessMethod: Tool
  config:
    pvcSize: 100Gi              # PVC 大小
    storageClassName: nfs-client # 使用的 StorageClass
  # PVC 模式不需要 credential
  pvReclaimPolicy: Retain
```

### 4.5 切换到 NFS

```bash
# 前置条件：安装 NFS CSI 驱动
# kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/main/deploy/example/nfs-csi-driver.yaml

kubectl apply -f - <<EOF
apiVersion: dataprotection.kubeblocks.io/v1alpha1
kind: BackupRepo
metadata:
  name: nfs-backuprepo
  annotations:
    dataprotection.kubeblocks.io/is-default-repo: "true"
spec:
  storageProviderRef: nfs
  accessMethod: Mount            # NFS 只能用 Mount 模式
  config:
    nfsServer: 192.168.1.100
    nfsPath: /backups/kubeblocks
    mountOptions: "nolock,hard,intr"
  pvReclaimPolicy: Retain
EOF
```

### 4.6 切换到阿里云 OSS

```bash
kubectl create secret generic oss-credential \
  -n kb-system \
  --from-literal=accessKeyId=LTAIXXXXXXXXXX \
  --from-literal=secretAccessKey=xxxxxxxxxxxx

kubectl apply -f - <<EOF
apiVersion: dataprotection.kubeblocks.io/v1alpha1
kind: BackupRepo
metadata:
  name: oss-backuprepo
  annotations:
    dataprotection.kubeblocks.io/is-default-repo: "true"
spec:
  storageProviderRef: oss
  accessMethod: Tool
  config:
    bucket: kubeblocks-backup
    region: cn-hangzhou
  credential:
    name: oss-credential
    namespace: kb-system
  pvReclaimPolicy: Retain
EOF
```

---

## 5. 验证切换成功

```bash
# 1. 确认新 BackupRepo 状态
kubectl get backuprepo
# NAME                     STATUS   DEFAULT   AGE
# nfs-backuprepo           Ready    true      1m
# minio-backuprepo         Ready    false     2d   ← 不再是默认

# 2. 触发一次手动备份验证
kubectl apply -n redis -f - <<EOF
apiVersion: dataprotection.kubeblocks.io/v1alpha1
kind: Backup
metadata:
  name: redis-verify-backup
spec:
  backupMethod: datafile
  backupPolicyName: redis-redis-backup-policy
  deletionPolicy: Delete
EOF

# 3. 观察备份完成
kubectl get backup -n redis -w

# 4. 检查目标存储上是否有数据
#   ─ AWS S3:  aws s3 ls s3://my-kubeblocks-backup/
#   ─ MinIO:   mc ls myminio/kubeblocks-backup/
#   ─ NFS:     ls /backups/kubeblocks/
```

---

## 6. 回滚方案

如果新存储有问题，回滚到 MinIO：

```bash
# 1. 将 minio-backuprepo 重新标记为默认
kubectl annotate backuprepo minio-backuprepo \
  dataprotection.kubeblocks.io/is-default-repo="true" \
  --overwrite

# 2. 取消新 repo 的默认标记
kubectl annotate backuprepo nfs-backuprepo \
  dataprotection.kubeblocks.io/is-default-repo- \
```

---

## 7. 多备份仓库场景

KubeBlocks 支持同时存在多个 BackupRepo，但**同一时间只有一个默认仓库**
（用 `is-default-repo: true` 标记）。非默认仓库可以用于：

- 手动指定特定备份存储
- 数据分级（热备份 → MinIO，归档备份 → 冷存储）
- 迁移过渡期双写

```yaml
# 手动备份到非默认仓库
kubectl apply -n redis -f - <<EOF
apiVersion: dataprotection.kubeblocks.io/v1alpha1
kind: Backup
metadata:
  name: redis-backup-to-archive
spec:
  backupMethod: datafile
  backupPolicyName: redis-redis-backup-policy
  backupRepoName: archive-backuprepo    # ← 指定非默认仓库
  deletionPolicy: Retain
EOF
```

---

## 8. 常见问题

### Q: 切换存储后，旧的备份还能用来恢复吗？
**可以。** Backup CR 中记录了它所属的 BackupRepo 引用。
恢复时 KubeBlocks 会从正确的 BackupRepo 读取数据，不受当前默认仓库的影响。

### Q: NFS 的 NotReady 状态怎么解决？
需要安装 NFS CSI 驱动：
```bash
# 部署 NFS CSI Driver
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/main/deploy/example/nfs-csi-driver.yaml
```
安装后 StorageProvider `nfs` 会自动变为 Ready。

### Q: Tool 和 Mount 模式有什么区别？
- **Tool**：备份 Pod 内启动 datasafed 进程，直接通过网络将数据流式上传到对象存储（S3 API）。
  不占用节点存储空间，不依赖 CSI 驱动。**推荐用于 S3 兼容后端。**
- **Mount**：备份 Pod 通过 CSI 驱动挂载存储卷，将数据写入挂载点（类似 NFS 挂载）。
  需要 CSI 驱动支持，数据先写到本地再同步。**NFS 等非对象存储必须用此模式。**

### Q: 备份数据在 MinIO 中存多久？
取决于 `retentionPeriod` 设置：
- `datafile` 全量保留 7 天
- `aof` 增量保留 2 天
过期后 KubeBlocks 会自动清理 Backup CR 和对应的存储数据。
