# Helm Chart: kube-prometheus-stack

## 来源

- **Chart**: kube-prometheus-stack 85.1.3
- **远程仓库**: `https://prometheus-community.github.io/helm-charts`
- **下载方式**:
  ```bash
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  helm pull prometheus-community/kube-prometheus-stack --version 85.1.3 --untar
  mv kube-prometheus-stack remote-kube-prometheus-stack-85.1.3
  ```
- **离线路径**: `remote-kube-prometheus-stack-85.1.3/`（禁止修改此目录）

## 本地安装

```bash
# 从本地离线 Chart 安装（使用预配置的 prod 环境 values）
helm upgrade --install kube-prometheus-stack ./remote-kube-prometheus-stack-85.1.3 \
  -n monitoring --create-namespace \
  -f ./values-prod.yaml

# 仅查看默认 values
helm show values ./remote-kube-prometheus-stack-85.1.3
```

## 目录说明

| 文件/目录 | 说明 |
|-----------|------|
| `remote-kube-prometheus-stack-85.1.3/` | 离线 Chart 文件，helm pull 原样保留，禁止修改 |
| `values-prod.yaml` | 生产环境配置覆盖（持久化、Ingress、资源限制等） |

## 关键配置

| 配置项 | values-prod.yaml 值 | 说明 |
|--------|---------------------|------|
| `grafana.persistence.enabled` | `true` | Grafana 5Gi PVC |
| `grafana.ingress.enabled` | `true` | Ingress: monitor.czw-sre.internal |
| `grafana.service.type` | `NodePort` | NodePort:30002 |
| `prometheus.prometheusSpec.retention` | `7d` | 指标保留 7 天 |
| `prometheus.prometheusSpec.storageSpec` | `10Gi` | Prometheus PVC |

包含组件：Prometheus Operator + Prometheus + Grafana + AlertManager + Node Exporter + kube-state-metrics。
完整配置见 `values-prod.yaml`。

## 注意事项

- 安装过程会创建大量 CRD（PrometheusRule、ServiceMonitor、PodMonitor 等）
- 首次安装需等待 1-2 分钟，CRD 注册完成后组件才会启动
- k3s 环境不包含 kube-controller-manager、kube-scheduler 等独立 metrics 端点，相关面板无数据属于正常情况

## 升级

```bash
# 下载新版离线 Chart
helm repo update
helm pull prometheus-community/kube-prometheus-stack --version <新版本> --untar
rm -rf remote-kube-prometheus-stack-<旧版本>
mv kube-prometheus-stack remote-kube-prometheus-stack-<新版本>

# 升级
helm upgrade kube-prometheus-stack ./remote-kube-prometheus-stack-<新版本> \
  -n monitoring -f ./values-prod.yaml
```

## 卸载

```bash
helm uninstall kube-prometheus-stack -n monitoring
kubectl delete namespace monitoring --ignore-not-found
```
