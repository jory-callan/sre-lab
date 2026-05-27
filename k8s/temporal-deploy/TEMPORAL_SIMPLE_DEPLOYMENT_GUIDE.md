# Temporal 单体版（temporal-simple）详细部署文档

## 一、架构说明

### 设计目标

和 docker-compose 部署方式类似，使用单体架构，而不是分布式架构。

### 架构图

```
temporal-simple 命名空间
├── [1] temporal-simple-mysql (MySQL 8.4)
│   └── 数据库: temporal, temporal_visibility
├── [2] temporal-simple-server (单体 Temporal Server) ✅
│   └── 包含: frontend + history + matching + worker
├── [3] temporal-simple-web (Web UI: temporalio/ui:2.49.1)
│   └── 访问地址: http://localhost:8080
└── [4] temporal-simple-admintools (管理工具)
    └── 包含: tctl, temporal-sql-tool 等工具
```

### 和分布式版（temporal-test）对比

| 特性 | temporal-test (分布式) | temporal-simple (单体) ✅ |
|------|-------------------------|--------------------------|
| Temporal Server Pod | 4 个独立 Pod<br>(frontend, history, matching, worker) | **1 个单体 Pod** ✅ |
| 总 Pod 数 | 7 个 | 4 个 |
| 适用场景 | 生产/测试环境 | 开发/本地环境 |
| 资源消耗 | 较高 | 较低 |

---

## 二、环境准备

### 前提条件

- ✅ Kubernetes 集群（本示例用 k3d）
- ✅ kubectl 已配置
- ✅ 本地已有镜像:
  - `mysql:8.4`
  - `temporalio/server:1.31.0`
  - `temporalio/ui:2.49.1`
  - `temporalio/admin-tools:1.31.0`

### 命名空间

```bash
kubectl create namespace temporal-simple
```

---

## 三、部署步骤

### 步骤 1: 部署 MySQL

**文件：** `/root/temporal-deploy/temporal-simple-mysql.yaml`

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: temporal-simple-mysql-pvc
  namespace: temporal-simple
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: temporal-simple-mysql
  namespace: temporal-simple
spec:
  replicas: 1
  selector:
    matchLabels:
      app: temporal-simple-mysql
  template:
    metadata:
      labels:
        app: temporal-simple-mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.4
        imagePullPolicy: IfNotPresent
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: temporal123
        - name: MYSQL_USER
          value: temporal
        - name: MYSQL_PASSWORD
          value: temporal123
        - name: MYSQL_DATABASE
          value: temporal
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: mysql-storage
          mountPath: /var/lib/mysql
      volumes:
      - name: mysql-storage
        persistentVolumeClaim:
          claimName: temporal-simple-mysql-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: temporal-simple-mysql
  namespace: temporal-simple
spec:
  selector:
    app: temporal-simple-mysql
  ports:
  - port: 3306
    targetPort: 3306
```

**部署命令：**
```bash
kubectl apply -f /root/temporal-deploy/temporal-simple-mysql.yaml
```

**等待 MySQL 就绪：**
```bash
kubectl wait --for=condition=ready pod -l app=temporal-simple-mysql -n temporal-simple --timeout=300s
```

**初始化数据库：**
```bash
kubectl exec deploy/temporal-simple-mysql -n temporal-simple -- mysql -uroot -ptemporal123 -e "CREATE DATABASE IF NOT EXISTS temporal; CREATE DATABASE IF NOT EXISTS temporal_visibility; GRANT ALL PRIVILEGES ON *.* TO 'temporal'@'%'; FLUSH PRIVILEGES;"
```

---

### 步骤 2: 部署单体版 Temporal

**文件：** `/root/temporal-deploy/temporal-simple.yaml`

这个文件包含以下资源：

| 资源类型 | 资源名称 | 说明 |
|---------|---------|------|
| ConfigMap | temporal-simple-config | Temporal 配置文件 |
| Secret | temporal-simple-secret | 数据库密码 |
| Service | temporal-simple-frontend | Temporal Server 服务 |
| Job | temporal-simple-schema | 数据库 Schema 初始化 |
| Deployment | temporal-simple-server | **单体 Temporal Server** ✅ |
| Service | temporal-simple-web | Web UI 服务 |
| Deployment | temporal-simple-web | Web UI 部署 |
| Deployment | temporal-simple-admintools | 管理工具 |

**关键配置说明（单体核心）：**

```yaml
env:
  - name: SERVICES
    value: "frontend,history,matching,worker"  # 关键：多个服务用逗号分隔！
  - name: TEMPORAL_SERVICES
    value: "frontend,history,matching,worker"
```

**部署命令：**
```bash
kubectl apply -f /root/temporal-deploy/temporal-simple.yaml
```

---

## 四、验证部署

### 查看 Pod 状态

```bash
kubectl get pods -n temporal-simple
```

**预期输出：**
```
NAME                                          READY   STATUS      RESTARTS   AGE
temporal-simple-admintools-6749c6d874-6zslm   1/1     Running     0          5m
temporal-simple-mysql-5ddb4d7c46-mcj9r        1/1     Running     0          10m
temporal-simple-schema-g8v7r                  0/1     Completed   0          5m
temporal-simple-server-7d4d6dd97c-4h77h       1/1     Running     2          5m
temporal-simple-web-6975c894bf-7wdc2          1/1     Running     0          2m
```

---

## 五、访问方式

### 1. 访问 Web UI

**开启端口转发：**
```bash
kubectl port-forward -n temporal-simple svc/temporal-simple-web 8080:8080
```

**在浏览器打开：**
```
http://localhost:8080
```

### 2. 访问 Temporal Frontend（gRPC）

**开启端口转发：**
```bash
kubectl port-forward -n temporal-simple svc/temporal-simple-frontend 7233:7233
```

**连接地址：**
```
localhost:7233
```

### 3. 使用 Admin Tools

**进入 Pod：**
```bash
kubectl exec -it -n temporal-simple deploy/temporal-simple-admintools -- sh
```

**使用 tctl 命令：**
```bash
tctl --address temporal-simple-frontend:7233 namespace list
tctl --address temporal-simple-frontend:7233 workflow list
```

---

## 六、配置说明

### 环境变量详解（单体部署关键）

| 环境变量 | 值 | 说明 |
|---------|---|------|
| `SERVICES` | `frontend,history,matching,worker` | **关键！** 指定在当前容器中运行哪些服务 |
| `TEMPORAL_SERVICES` | `frontend,history,matching,worker` | 同上，兼容性变量 |
| `TEMPORAL_SERVER_CONFIG_FILE_PATH` | `/etc/temporal/config/config_template.yaml` | 配置文件路径 |
| `POD_IP` | (downward API) | Pod IP，用于成员发现 |

### 配置文件要点

```yaml
services:
  frontend:
    rpc:
      grpcPort: 7233
      httpPort: 7243
      membershipPort: 6933
  history:
    rpc:
      grpcPort: 7234
      membershipPort: 6934
  matching:
    rpc:
      grpcPort: 7235
      membershipPort: 6935
  worker:
    rpc:
      membershipPort: 6939

publicClient:
  hostPort: "127.0.0.1:7233"  # 单体模式下用 127.0.0.1
```

---

## 七、常见问题

### Q1: 为什么 MySQL 服务名不用 `mysql`？

**A:** 避免环境变量冲突！

如果服务名叫 `mysql`，Kubernetes 会自动注入环境变量：
- `MYSQL_PORT=tcp://...`

但是 Temporal schema 工具期望：
- `MYSQL_PORT=3306` (纯数字)

**解决方案：** 服务名用 `temporal-simple-mysql`，这样不会有冲突的环境变量。

### Q2: 如何查看 Server 日志？

```bash
kubectl logs -n temporal-simple deploy/temporal-simple-server -f
```

### Q3: 如何重新初始化 Schema？

```bash
# 删除旧的 Job
kubectl delete job -n temporal-simple temporal-simple-schema

# 清理数据库
kubectl exec deploy/temporal-simple-mysql -n temporal-simple -- mysql -uroot -ptemporal123 -e "DROP DATABASE IF EXISTS temporal; DROP DATABASE IF EXISTS temporal_visibility; CREATE DATABASE temporal; CREATE DATABASE temporal_visibility; GRANT ALL PRIVILEGES ON *.* TO 'temporal'@'%'; FLUSH PRIVILEGES;"

# 重新部署
kubectl apply -f /root/temporal-deploy/temporal-simple.yaml
```

### Q4: 如何删除整个部署？

```bash
kubectl delete namespace temporal-simple
```

或者删除单个文件部署的资源：
```bash
kubectl delete -f /root/temporal-deploy/temporal-simple.yaml
kubectl delete -f /root/temporal-deploy/temporal-simple-mysql.yaml
```

---

## 八、文件清单

| 文件 | 位置 | 说明 |
|------|------|------|
| MySQL 部署文件 | `/root/temporal-deploy/temporal-simple-mysql.yaml` | MySQL PVC/Deployment/Service |
| Temporal 单体部署文件 | `/root/temporal-deploy/temporal-simple.yaml` | 完整的单体版部署文件 |
| 分布式版部署文档 | `/root/temporal-deploy/TEMPORAL_OFFLINE_DEPLOYMENT_GUIDE.md` | 分布式版详细部署说明 |

---

## 九、快速命令参考

```bash
# 查看 Pod
kubectl get pods -n temporal-simple

# 查看日志
kubectl logs -n temporal-simple deploy/temporal-simple-server -f

# 端口转发 - Web UI
kubectl port-forward -n temporal-simple svc/temporal-simple-web 8080:8080

# 端口转发 - Frontend
kubectl port-forward -n temporal-simple svc/temporal-simple-frontend 7233:7233

# 进入 Admin Tools
kubectl exec -it -n temporal-simple deploy/temporal-simple-admintools -- sh
```

---

## 十、总结

✅ **单体版优势：**
- 资源占用少
- 部署简单
- 适合开发/测试
- 一个 Pod 包含所有 Temporal 服务

📌 **当前部署版本：**
- Temporal Server: 1.31.0
- Temporal UI: 2.49.1
- MySQL: 8.4
