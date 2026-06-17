# Helm Chart: kite

## 来源

- **Chart**: kite 0.12.2（自定义 Chart，非 remote 方式）
- **远程来源**: `ghcr.io/kite-org/charts/kite`（OCI 镜像）
- **类型**: application

## 本地安装

```bash
# 从本地目录安装（使用预配置的 prod 环境 values）
helm upgrade --install kite . \
  -n kite --create-namespace \
  -f ./values-prod.yaml
```

## 目录说明

| 文件/目录 | 说明 |
|-----------|------|
| `values.yaml` | Chart 默认 values，上游提供，不做修改 |
| `values-prod.yaml` | 本环境配置覆盖（持久化、Ingress、NodePort 等） |
| `templates/` | Chart 模板 |
| `Chart.yaml` | Chart 元数据 |

## 关键配置

| 配置项 | values-prod.yaml 值 | 说明 |
|--------|---------------------|------|
| `deploymentStrategy.type` | `Recreate` | SQLite + RWO PVC 必须 |
| `db.sqlite.persistence.pvc.enabled` | `true` | 启用 PVC 持久化 |
| `ingress.enabled` | `true` | 开启 Ingress |
| `service.type` | `NodePort` | 暴露 NodePort:30001 |

完整配置见 `values-prod.yaml`。

## 升级

```bash
helm upgrade kite . -n kite -f ./values-prod.yaml
```

## 卸载

```bash
helm uninstall kite -n kite
kubectl delete namespace kite --ignore-not-found
```
