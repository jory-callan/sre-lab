# kube-prometheus-stack - K8s 标准监控栈

Kubernetes 社区推荐的监控方案，包含完整的企业级监控组件。

## 组件一览

```
┌─────────────────────────────────────────────────────┐
│                    Grafana                           │
│  NodePort:30002 │ Ingress: monitor.czw-sre.internal  │
│  默认: admin / admin123                              │
└──────────────────────┬──────────────────────────────┘
                       │ 查询
┌──────────────────────▼──────────────────────────────┐
│                   Prometheus                         │
│  10Gi PVC │ 保留 7d │ ClusterIP:9090                 │
└──────┬──────────┬──────────┬─────────────────────────┘
       │          │          │
  采集节点    采集对象   kube-state-metrics
  ↓            ↓           ↓
┌─────────┐ ┌─────────┐ ┌──────────────┐
│Node      │ │各 Pod   │ │集群对象状态   │
│Exporter  │ │指标     │ │(Deploy/Pod…) │
└─────────┘ └─────────┘ └──────────────┘
```

- **命名空间**：`monitoring`
- **存储**：Grafana 5Gi + Prometheus 10Gi，均为 local-path PVC
- **Grafana 访问**：NodePort:30002 + Ingress `monitor.czw-sre.internal`
- **Prometheus 访问**：仅集群内部（通过 Grafana 查询）
- **告警**：AlertManager 已部署，默认空路由（仅抑制，不发送通知）

## 快速开始

```bash
# 安装
./install.sh

# 卸载
./uninstall.sh
```

## 验收确认

```bash
# 查看 Pod 状态
kubectl get pods -n monitoring
# 期望输出（5-8 个 Pod 均为 Running）：
#   alertmanager-xxxxx                 2/2     Running
#   prometheus-kube-prometheus-stack-prometheus-0  2/2     Running
#   grafana-xxxxx                      1/1     Running
#   kube-state-metrics-xxxxx           1/1     Running
#   prometheus-node-exporter-xxxxx     1/1     Running  (每节点一个)
#   prometheus-operator-xxxxx          1/1     Running

# 查看 Service
kubectl get svc -n monitoring
# 期望输出包含：
#   prometheus-operated          ClusterIP  10.43.xx.xx  9090/TCP
#   kube-prometheus-stack-grafana NodePort   10.43.xx.xx  80:30002/TCP

# 查看 Ingress
kubectl get ingress -n monitoring
#   grafana   monitor.czw-sre.internal   192.168.5.240   80

# 查看 PVC
kubectl get pvc -n monitoring
#   kube-prometheus-stack-grafana    Bound    ...   5Gi   RWO   local-path
#   prometheus-kube-prometheus-stack-prometheus-db-prometheus-...  Bound  ...  10Gi  RWO  local-path

# 查看 Grafana Web 界面
curl -s http://<节点IP>:30002/api/health
# 期望输出：{"message":"Grafana is running"}
```

### 访问地址

| 服务 | 方式 | 地址 |
|------|------|------|
| Grafana | 域名 | http://monitor.czw-sre.internal（需 hosts 指向 192.168.5.240） |
| Grafana | NodePort | http://\<任一节点IP\>:30002 |
| Grafana | 默认账号 | admin / admin123 |

### Grafana 预置仪表板

安装后自动部署的 K8s 仪表板（在 Grafana 中搜索）：

| 仪表板 | 说明 |
|--------|------|
| Kubernetes / Views | 集群概览 |
| Kubernetes / Nodes | 节点资源使用 |
| Kubernetes / Pods | Pod 资源使用 |
| Kubernetes / API Server | API Server 状态 |
| Node Exporter / Nodes | 节点系统指标 |
| Node Exporter / USE Method | 节点 USE 方法 |

## 卸载

```bash
./uninstall.sh
```

## 注意

- 首次部署 CRD 安装需要 1-2 分钟，`--wait` 等待超时可手动 `kubectl get pods -n monitoring` 观察
- Grafana 默认密码 `admin123`，首次部署后请及时修改
- 3 节点集群总资源消耗约：CPU < 1 核，内存 < 2Gi
- Prometheus 仅单副本，重启时会有短暂监控中断
