# Helm Chart: Percona PS Operator（cluster 模式专用）

> standalone 模式不需要 Helm，使用 `../manifests/` 中的原生 YAML 通过 `kubectl apply` 部署。

## 来源

- **Chart**: ps-operator 1.1.0（仅 operator）
- **远程仓库**: `https://percona.github.io/percona-helm-charts/`
- **下载方式**:
  ```bash
  helm repo add percona https://percona.github.io/percona-helm-charts/
  helm pull percona/ps-operator --version 1.1.0 --untar
  mv ps-operator remote-ps-operator-1.1.0
  ```
- **离线路径**: `remote-ps-operator-1.1.0/`（禁止修改此目录）

## 本地安装（cluster 模式）

```bash
# 1. 安装 operator
helm upgrade --install ps-operator ./remote-ps-operator-1.1.0 \
  -n mysql-operator --create-namespace \
  -f ./values-operator.yaml

# 2. 创建 InnoDB Cluster CR
kubectl apply -f ../operator/common/secret.yaml
kubectl apply -f ../operator/cluster/mysql-cr.yaml
kubectl apply -f ../operator/cluster/service-external.yaml
```

## 目录说明

| 文件/目录 | 说明 |
|-----------|------|
| `remote-ps-operator-1.1.0/` | 离线 Chart，helm pull 原样保留，禁止修改 |
| `values-operator.yaml` | Operator 配置（资源限制、命名覆盖） |

## 升级

```bash
helm upgrade ps-operator ./remote-ps-operator-1.1.0 -n mysql-operator -f ./values-operator.yaml
```

## 卸载

```bash
helm uninstall ps-operator -n mysql-operator
```
