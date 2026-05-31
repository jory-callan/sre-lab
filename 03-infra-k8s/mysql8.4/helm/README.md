# Helm Chart: Percona PS Operator

## 来源

- **Chart**: ps-operator 1.1.0（仅 operator，不含 CRD 实例）
- **远程仓库**: `https://percona.github.io/percona-helm-charts/`
- **下载方式**:
  ```bash
  helm repo add percona https://percona.github.io/percona-helm-charts/
  helm repo update
  helm pull percona/ps-operator --version 1.1.0 --untar
  mv ps-operator remote-ps-operator-1.1.0
  ```
- **离线路径**: `remote-ps-operator-1.1.0/`（禁止修改此目录）

## 本地安装

```bash
# 只安装 operator（不创建数据库实例）
helm upgrade --install ps-operator ./remote-ps-operator-1.1.0 \
  -n mysql-operator --create-namespace \
  -f ./values-prod.yaml

# 安装完成后使用 kubectl 创建 PerconaServerMySQL CR
kubectl apply -f ../operator/common/secret.yaml
kubectl apply -f ../operator/standalone/mysql-cr.yaml
```

## 目录说明

| 文件/目录 | 说明 |
|-----------|------|
| `remote-ps-operator-1.1.0/` | 离线 Chart，helm pull 原样保留，禁止修改 |
| `remote-ps-db-1.1.0/` | 离线 Database Chart（参考用，实际通过 kubectl apply CR 部署） |
| `values-prod.yaml` | Operator 资源限制配置 |

## 关键配置

- `watchAllNamespaces: true` — 允许监控所有命名空间中的 CR
- Operator 资源: request 100m/64Mi, limit 300m/256Mi

## 升级

```bash
# 1. 下载新版 chart
helm pull percona/ps-operator --version <新版> --untar
mv ps-operator remote-ps-operator-<新版>

# 2. 升级 operator
helm upgrade ps-operator ./remote-ps-operator-<新版> \
  -n mysql-operator -f ./values-prod.yaml
```

## 卸载

```bash
helm uninstall ps-operator -n mysql-operator
```
