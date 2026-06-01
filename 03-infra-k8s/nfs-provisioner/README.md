# NFS Subdir External Provisioner

为 K8s 集群提供基于 NFS 的动态存储供应，解决 `local-path` 在节点重启后数据丢失问题。

## 架构

```
NFS Server: 192.168.5.249 (k3s-server-1)
共享目录: /srv/nfs/k8s/
StorageClass: nfs-storage
Provisioner: registry.k8s.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2
```

## 部署

```bash
kubectl apply -f namespace.yaml
kubectl apply -f rbac.yaml
kubectl apply -f deployment.yaml
kubectl apply -f storageclass.yaml
```

## 使用

所有需要持久化的 PVC 只需指定 `storageClassName: nfs-storage`：

```yaml
spec:
  storageClassName: nfs-storage
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

每个 PVC 在 NFS 上会自动创建子目录：
`/srv/nfs/k8s/{namespace}-{pvcName}-{pvName}/`

## 注意

- NFS 服务器在 k3s-server-1（192.168.5.249）上运行，此节点不能关机
- 如果 NFS 服务器挂掉，所有使用 nfs-storage 的 Pod 将无法启动
- 建议将 NFS 服务器放在稳定的宿主机上
- 镜像走 Daocloud 代理：`m.daocloud.io/registry.k8s.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2`
