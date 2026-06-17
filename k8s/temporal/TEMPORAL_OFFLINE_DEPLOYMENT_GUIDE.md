# Temporal 离线部署完整文档

## 一、架构介绍

### 1.1 Temporal 架构
Temporal 是一个分布式、可扩展、持久化、高可用的编排引擎，用于执行异步长时间运行的业务逻辑。

**核心组件：**
- **Frontend**：API 网关，处理客户端请求
- **History**：管理工作流执行历史
- **Matching**：任务队列管理
- **Worker**：执行工作流和活动的组件
- **Web UI**：Web 管理界面
- **Admin Tools**：管理工具

### 1.2 本次部署架构
```
┌─────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                    │
│                    (temporal-test NS)                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │   Frontend   │  │   History    │  │  Matching    │ │
│  │   (1 replica)│  │  (1 replica) │  │ (1 replica)  │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │    Worker    │  │   Web UI     │  │ Admin Tools  │ │
│  │  (1 replica) │  │  (1 replica) │  │ (1 replica)  │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│  ┌───────────────────────────────────────────────────┐ │
│  │              MySQL 8.4 (1 replica)                │ │
│  │  - Database: temporal                             │ │
│  │  - Database: temporal_visibility                  │ │
│  └───────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## 二、环境信息

| 项目 | 详情 |
|------|------|
| Kubernetes 集群 | k3d (k3s) |
| 命名空间 | temporal-test |
| Temporal 版本 | 1.31.0 |
| Helm Chart 版本 | 1.2.0 |
| 数据库 | MySQL 8.4 |
| 部署方式 | 离线部署（使用本地已下载的 chart） |

## 三、部署前准备

### 3.1 问题：GitHub 无法访问
**问题描述：** 位于国内，无法直接访问 `github.com`

**解决方案：** 使用代理 `gh-proxy.com/github.com`

### 3.2 部署步骤总览
1. 安装 Helm
2. 下载 Temporal Helm Chart
3. 部署数据库
4. 配置并部署 Temporal

---

## 四、详细部署过程

### 4.1 步骤 1：安装 Helm

**操作：**
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

**结果：** ✅ Helm v3.21.0 安装成功

---

### 4.2 步骤 2：下载 Temporal Helm Chart

**操作：**
```bash
mkdir -p /root/temporal-deploy && cd /root/temporal-deploy
curl -L https://gh-proxy.com/github.com/temporalio/helm-charts/archive/refs/heads/main.tar.gz -o temporal-helm.tar.gz
tar -xzf temporal-helm.tar.gz
```

**结果：** ✅ Chart 下载成功，位置：`/root/temporal-deploy/helm-charts-main`

---

### 4.3 步骤 3：创建命名空间

**操作：**
```bash
kubectl create namespace temporal-test
```

**结果：** ✅ 命名空间创建成功

---

### 4.4 步骤 4：部署数据库（第一次尝试：PostgreSQL）

#### 踩坑记录 #1：PostgreSQL 镜像拉取失败

**问题描述：**
- 尝试部署 PostgreSQL 14-alpine
- 集群配置了私有镜像仓库 `192.168.5.103:5000`，但该仓库无法访问
- Pod 状态：ImagePullBackOff

**错误日志：**
```
Failed to pull image "postgres:14-alpine": failed to resolve reference "docker.io/library/postgres:14-alpine": failed to do request: Head "https://192.168.5.103:5000/v2/library/postgres/manifests/14-alpine?ns=docker.io": dial tcp 192.168.5.103:5000: connect: connection refused
```

**解决路径：**
1. 检查集群中已有的镜像：`crictl images`
2. 发现 `mysql:8.4` 镜像已存在

**解决方案：** 改用 MySQL 8.4 作为数据库

---

### 4.5 步骤 5：部署 MySQL（第二次尝试）

**操作：**
创建 `/root/temporal-deploy/mysql.yaml`：
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
  namespace: temporal-test
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
  name: mysql
  namespace: temporal-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
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
          claimName: mysql-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: mysql
  namespace: temporal-test
spec:
  selector:
    app: mysql
  ports:
  - port: 3306
    targetPort: 3306
```

然后部署：
```bash
kubectl apply -f /root/temporal-deploy/mysql.yaml
```

#### 踩坑记录 #2：服务名与环境变量冲突

**问题描述：**
- MySQL 服务名为 `mysql`
- Kubernetes 自动注入环境变量 `MYSQL_PORT=tcp://10.43.78.215:3306`
- Temporal schema 工具需要纯数字的 `MYSQL_PORT` 环境变量
- 导致 panic 错误

**错误日志：**
```
panic: error getting env MYSQL_PORT
goroutine 1 [running]:
go.temporal.io/server/temporal/environment.GetMySQLPort()
```

**解决路径：**
1. 分析环境变量冲突问题
2. 意识到 Kubernetes 会为 Service 注入 `<SERVICE_NAME>_PORT` 环境变量
3. 决定更改服务名避免冲突

**解决方案：** 将 MySQL 服务名改为 `temporal-mysql`

---

### 4.6 步骤 6：重新部署 MySQL（服务名改为 temporal-mysql）

**操作：**
创建 `/root/temporal-deploy/temporal-mysql.yaml`（服务名改为 `temporal-mysql`），然后：
```bash
kubectl delete -f /root/temporal-deploy/mysql.yaml -n temporal-test
kubectl apply -f /root/temporal-deploy/temporal-mysql.yaml
```

**结果：** ✅ MySQL 部署成功，服务名：`temporal-mysql`

---

### 4.7 步骤 7：配置 Temporal values 文件

**操作：**
创建 `/root/temporal-deploy/values.yaml`：
```yaml
server:
  config:
    persistence:
      defaultStore: default
      visibilityStore: visibility
      numHistoryShards: 512
      datastores:
        default:
          sql:
            pluginName: mysql8
            databaseName: temporal
            connectAddr: "temporal-mysql.temporal-test.svc.cluster.local:3306"
            connectProtocol: "tcp"
            user: temporal
            password: temporal123
            createDatabase: false
            manageSchema: true
            maxConns: 20
            maxIdleConns: 20
            maxConnLifetime: "1h"
        visibility:
          sql:
            pluginName: mysql8
            databaseName: temporal_visibility
            connectAddr: "temporal-mysql.temporal-test.svc.cluster.local:3306"
            connectProtocol: "tcp"
            user: temporal
            password: temporal123
            createDatabase: false
            manageSchema: true
            maxConns: 20
            maxIdleConns: 20
            maxConnLifetime: "1h"
```

---

### 4.8 步骤 8：第一次部署 Temporal（失败）

#### 踩坑记录 #3：数据库权限不足

**问题描述：**
- 使用 `temporal` 用户尝试创建数据库 `temporal_visibility`
- 该用户没有创建数据库的权限

**错误日志：**
```
ERROR Unable to create SQL database. 
{"error": "Error 1044 (42000): Access denied for user 'temporal'@'%' to database 'temporal_visibility'"}
```

**解决路径：**
1. 检查用户权限
2. 决定使用 root 用户先手动创建数据库并授权

**解决方案：** 
1. 用 root 用户手动创建数据库
2. 给 `temporal` 用户授权所有权限
3. 在 values 文件中设置 `createDatabase: false`

---

### 4.9 步骤 9：手动创建数据库并授权

**操作：**
```bash
kubectl exec deploy/temporal-mysql -n temporal-test -- mysql -uroot -ptemporal123 -e "CREATE DATABASE IF NOT EXISTS temporal; CREATE DATABASE IF NOT EXISTS temporal_visibility; GRANT ALL PRIVILEGES ON *.* TO 'temporal'@'%'; FLUSH PRIVILEGES;"
```

**结果：** ✅ 数据库创建成功，权限已授权

---

### 4.10 步骤 10：第二次部署 Temporal（失败）

#### 踩坑记录 #4：数据库 schema 版本不兼容

**问题描述：**
- 第一次部署失败后，数据库中遗留了旧版本 schema
- 第二次部署时，Temporal server 检查到 schema 版本不匹配

**错误日志：**
```
sql schema version compatibility check failed: version mismatch for keyspace/database: "temporal_visibility". Expected version: 1.14 cannot be greater than Actual version: 1.1
```

**解决路径：**
1. 清理旧数据库
2. 重新创建空数据库
3. 重新部署 Temporal 让其初始化 schema

**解决方案：** 
- 删除旧数据库
- 重新创建空数据库
- 重新部署

---

### 4.11 步骤 11：清理数据库并最终部署

**操作：**
```bash
# 卸载 Temporal
helm uninstall temporal -n temporal-test

# 清理数据库
kubectl exec deploy/temporal-mysql -n temporal-test -- mysql -uroot -ptemporal123 -e "DROP DATABASE IF EXISTS temporal; DROP DATABASE IF EXISTS temporal_visibility; CREATE DATABASE temporal; CREATE DATABASE temporal_visibility; GRANT ALL PRIVILEGES ON *.* TO 'temporal'@'%'; FLUSH PRIVILEGES;"

# 重新部署
cd /root/temporal-deploy/helm-charts-main/charts/temporal
helm install temporal -f /root/temporal-deploy/values.yaml -n temporal-test --timeout 900s .
```

---

## 五、部署成功！

**最终状态：**
```
NAME                                   READY   STATUS      RESTARTS   AGE
temporal-admintools-76f8d6b859-pwkp4   1/1     Running     0          45s
temporal-frontend-575bd85777-n4shk     1/1     Running     0          45s
temporal-history-66b688b597-c4vqj      1/1     Running     0          45s
temporal-matching-748778469b-z265q     1/1     Running     0          45s
temporal-schema-1-2-0-1-z87wg          0/1     Completed   0          86s
temporal-web-6cfd866d5-lhrg8           1/1     Running     0          45s
temporal-worker-764cf479f7-7796k       1/1     Running     0          45s
temporal-mysql-8fdf85d4b-pkjqh         1/1     Running     0          8m21s
```

✅ **部署成功！**

---

## 六、踩坑总结与解决方案

| # | 问题 | 原因 | 解决方案 |
|---|------|------|----------|
| 1 | GitHub 无法访问 | 国内网络限制 | 使用 `gh-proxy.com/github.com` 代理 |
| 2 | PostgreSQL 镜像拉取失败 | 私有镜像仓库不可用 | 改用集群中已有的 `mysql:8.4` 镜像 |
| 3 | Temporal schema panic：`error getting env MYSQL_PORT` | Kubernetes Service 自动注入的 `MYSQL_PORT` 环境变量格式与 Temporal 期望的冲突 | 将 MySQL 服务名改为 `temporal-mysql`，避免环境变量冲突 |
| 4 | Access denied for user 'temporal'@'%' to database 'temporal_visibility' | 用户权限不足，无法创建数据库 | 用 root 用户手动创建数据库并给 temporal 用户授权所有权限，设置 `createDatabase: false` |
| 5 | schema version mismatch | 数据库中遗留旧版本 schema | 清理旧数据库，重新创建空数据库后重新部署 |

---

## 七、文件清单

| 文件/目录 | 位置 | 说明 |
|-----------|------|------|
| Temporal Helm Chart | `/root/temporal-deploy/helm-charts-main/charts/temporal` | 从 GitHub 下载的 chart |
| Values 文件 | `/root/temporal-deploy/values.yaml` | Temporal 配置文件 |
| MySQL 部署文件 | `/root/temporal-deploy/temporal-mysql.yaml` | MySQL 部署清单 |

---

## 八、后续操作建议

1. **数据持久化：** 当前使用的是单实例 MySQL，生产环境建议使用主从复制或集群
2. **高可用：** 增加 Temporal 各组件的副本数
3. **监控：** 配置 Prometheus + Grafana 监控
4. **Ingress：** 配置 Ingress 暴露 Web UI 和 Frontend 服务
5. **备份：** 定期备份 MySQL 数据库
