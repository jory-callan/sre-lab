# Kite - Kubernetes Web UI 管理面板

Kite 是一个开源的 Kubernetes Web UI，提供基于浏览器的集群管理界面。
通过 ServiceAccount 和 RBAC 绑定，Kite 可以管理集群中的所有资源。

## 部署架构

```
客户端 (浏览器)
    │
    ▼  http://kite.czw-sre.internal
┌─────────────────────────────────────┐
│  ingress-nginx (192.168.5.240)     │
│  └─ Ingress: kite.czw-sre.internal │
└─────────┬───────────────────────────┘
          ▼
┌──────────────────┐     ┌──────────────────┐
│  Service:kite    │ ──▶ │  Pod:kite        │
│  ClusterIP:8080  │     │  :8080/healthz   │
└──────────────────┘     └────────┬─────────┘
                                  │ 挂载
                                  ▼
                         ┌──────────────────┐
                         │  PVC:kite-storage │
                         │  (SQLite 数据)    │
                         └──────────────────┘
```

- **域名**：`kite.czw-sre.internal`（通过 ingress-nginx 暴露）
- **NodePort**：`30001`（任一节点 IP:30001 可直接访问）
- **数据库**：SQLite（嵌入式，通过 PVC 持久化到宿主机）
- **存储**：1Gi PVC，local-path StorageClass（k3s 默认）
- **授权**：ServiceAccount + cluster-admin ClusterRoleBinding
- **认证**：JWT 令牌（默认无认证，首次访问设置管理员账号）

## 快速开始

### 方式一：Manifests（默认）
```bash
# 安装
./install.sh

# 卸载
./uninstall.sh
```

### 方式二：Helm（推荐，支持更多配置）
```bash
# 安装
./install.sh helm

# 卸载
./uninstall.sh helm
```

### 配置 hosts（本地访问）
在 `/etc/hosts` 添加：
```
192.168.5.240 kite.czw-sre.internal
```

### 访问
浏览器打开：http://kite.czw-sre.internal

## 验收确认

确认部署成功：

```bash
# 查看 Pod 状态
kubectl get pods -n kite
# 期望输出：NAME                    READY   STATUS    RESTARTS   AGE
#           kite-xxxxx-xxxxx       1/1     Running   0          xx

# 查看 Ingress
kubectl get ingress -n kite
# 期望输出：NAME   HOSTS                    ADDRESS         PORTS   AGE
#           kite   kite.czw-sre.internal   192.168.5.240   80      xx

# 查看 PVC
kubectl get pvc -n kite
# 期望输出：NAME           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS
#           kite-storage   Bound    pvc-xxxxx-xxxxx                           1Gi        RWO            local-path
```

### 访问地址
- **域名**：http://kite.czw-sre.internal（需 hosts 指向 192.168.5.240）
- **NodePort**：http://\<任一节点IP\>:30001
- **首次访问**：设置用户名和密码创建管理员账号

### 日志查看
```bash
kubectl logs -n kite -l app=kite
```

## 持久化

数据存储在 PVC 中，卸载时默认保留 PVC 不删除数据。
如需彻底删除数据：
```bash
kubectl delete pvc -n kite kite-storage
```

## 注意

- SQLite 模式只支持单副本，Deployment 使用 `Recreate` 策略
- ServiceAccount 绑定 `cluster-admin`，Kite UI 拥有全集群管理权限
