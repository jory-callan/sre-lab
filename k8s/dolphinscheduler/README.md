# DolphinScheduler + SeaTunnel Engine

> 工作流调度系统（DolphinScheduler 3.1.7）+ 数据集成引擎（SeaTunnel 2.3.13）
> 原始资源：https://github.com/apache/dolphinscheduler | https://github.com/apache/seatunnel

## 架构

所有组件部署在 `dolphinscheduler` 命名空间内，通过内部 DNS 互通。

```
dolphinscheduler ns
├── ds-zookeeper          # ZooKeeper 注册中心（1节点）
├── ds-master             # DS Master（StatefulSet, 1副本）
├── ds-worker             # DS Worker（StatefulSet, 1副本, 含Python3.10+SeaTunnel客户端）
├── ds-api                # DS API（Deployment, 1副本）
├── ds-alert              # DS Alert（Deployment, 1副本）
├── st-*                  # SeaTunnel Engine（StatefulSet, 3节点）
└── 外部依赖
    └── pg-ha-rw.postgres.svc:5432  # PostgreSQL（外部）
```

## 前提条件

| 工具 | 版本 | 说明 |
|------|------|------|
| Kubernetes | 1.23+ | 已配置 kubectl 访问 |
| Helm | 3.0+ | 已配置 |
| StorageClass | nfs-client | 默认，可替换 |
| Prometheus Operator | — | 需要 ServiceMonitor CRD |

## 部署

### 快速部署

```bash
cd k8s/dolphinscheduler
bash install.sh
```

### 分步部署

1. 创建命名空间

```bash
kubectl create namespace dolphinscheduler --dry-run=client -o yaml | kubectl apply -f -
```

2. 部署 ZooKeeper

```bash
kubectl apply -f zookeeper/zookeeper.yaml
kubectl rollout status statefulset/ds-zookeeper -n dolphinscheduler
```

3. 部署 DolphinScheduler

```bash
helm upgrade --install ds ./dolphinscheduler/chart \
  --namespace dolphinscheduler \
  --values ./dolphinscheduler/values.yaml \
  --timeout 30m
```

4. 部署 SeaTunnel Engine

```bash
helm upgrade --install st ./seatunnel-engine \
  --namespace dolphinscheduler \
  --timeout 5m
```

### 构建自定义镜像

Worker 镜像包含 Python 3.10 + SeaTunnel 客户端：

```bash
export SEATUNNEL_VERSION=2.3.13
export SEATUNNEL_URL=https://gh-proxy.com/https://github.com/apache/seatunnel/releases/download/${SEATUNNEL_VERSION}/apache-seatunnel-${SEATUNNEL_VERSION}-bin.tar.gz

docker build \
  --build-arg SEATUNNEL_VERSION=${SEATUNNEL_VERSION} \
  --build-arg SEATUNNEL_URL=${SEATUNNEL_URL} \
  -t 192.168.5.103:5001/ds-worker-custom:3.1.7 \
  -f dolphinscheduler/custom-image/Dockerfile \
  dolphinscheduler/custom-image/
docker push 192.168.5.103:5001/ds-worker-custom:3.1.7

docker build \
  --build-arg SEATUNNEL_VERSION=${SEATUNNEL_VERSION} \
  --build-arg SEATUNNEL_URL=${SEATUNNEL_URL} \
  -t 192.168.5.103:5001/seatunnel-engine:2.3.13 \
  -f seatunnel-engine/custom-image/Dockerfile \
  seatunnel-engine/custom-image/
docker push 192.168.5.103:5001/seatunnel-engine:2.3.13
```

## 访问

### DolphinScheduler UI

```bash
kubectl port-forward -n dolphinscheduler svc/ds-api 12345:12345
```

浏览器打开 http://127.0.0.1:12345/dolphinscheduler

默认管理员账号：`admin` / `dolphinscheduler123`

### SeaTunnel 连接

DS 的 SeaTunnel 任务节点中配置：

| 参数 | 值 |
|------|-----|
| 部署模式 | cluster |
| 集群地址 | `st.dolphinscheduler.svc:5802` |
| 客户端路径 | `/opt/seatunnel` |

## 监控

各组件已配置 ServiceMonitor，由 Prometheus Operator 自动发现：

| 组件 | 端口 | Metrics 路径 |
|------|------|-------------|
| DS API | 12345 (api-port) | /dolphinscheduler/actuator/prometheus |
| DS Alert | 50053 (actuator-port) | /actuator/prometheus |
| DS Master | 5679 (metrics-port) | /actuator/prometheus |
| DS Worker | 1235 (metrics-port) | /actuator/prometheus |
| SeaTunnel Engine | 5802 (engine-api) | /metrics |

ServiceMonitor 默认 label 为 `release: kube-prometheus-stack`，若使用 VictoriaMetrics 或其他监控栈，在 `values.yaml` 中修改 `serviceMonitor.labels`。

## 资源限制

仅设置内存 limit，不设 CPU 限制（避免 CPU 节流影响任务性能）：

| 组件 | 内存 limit |
|------|-----------|
| DS Master | 1Gi |
| DS Worker | 2Gi |
| DS API | 1Gi |
| DS Alert | 512Mi |
| ZooKeeper | 1Gi |
| SeaTunnel Engine | 8Gi |

## 端口说明

| 组件 | 端口 | 用途 |
|------|------|------|
| ds-zookeeper | 2181 | 客户端连接 |
| ds-master | 5678 | 主服务 |
| ds-master | 5679 | Actuator/Metrics |
| ds-worker | 1234 | 主服务 |
| ds-worker | 1235 | Actuator/Metrics |
| ds-api | 12345 | API 服务 |
| ds-api | 25333 | Python API |
| ds-alert | 50052 | Alert 服务 |
| ds-alert | 50053 | Actuator/Metrics |
| st engine | 5801 | Hazelcast 集群通信 |
| st engine | 5802 | Engine API |

## 卸载

```bash
cd k8s/dolphinscheduler
bash uninstall.sh
```

## 日常运维

```bash
# 查看 Pod
kubectl get pods -n dolphinscheduler

# 查看日志
kubectl logs -n dolphinscheduler ds-worker-0
kubectl logs -n dolphinscheduler st-0

# 扩容 Worker
kubectl scale statefulset ds-worker -n dolphinscheduler --replicas=3

# 扩容 SeaTunnel（修改 values.yaml 中 replicaCount 后重新 helm upgrade）
# 注意：扩容后需同步更新 configmap 中的 hazelcast member-list

# 更新 Worker 镜像
kubectl set image statefulset/ds-worker -n dolphinscheduler \
  ds-worker=192.168.5.103:5000/ds-worker-custom:3.1.7-new
```
