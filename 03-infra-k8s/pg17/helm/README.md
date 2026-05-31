# Helm Chart: CloudNativePG

## 来源

- **Chart**: cloudnative-pg 0.28.2
- **应用版本**: 1.26.x（PostgreSQL Operator）
- **远程仓库**: `https://cloudnative-pg.github.io/charts/`
- **下载方式**:
  ```bash
  helm repo add cnpg https://cloudnative-pg.github.io/charts/
  helm repo update
  helm pull cnpg/cloudnative-pg --version 0.28.2 --untar
  mv cloudnative-pg remote-cloudnative-pg-0.28.2
  ```
  > ⚠️ 国内环境可用 gh-proxy 下载 GitHub Release：
  > ```bash
  > curl -sL "https://gh-proxy.com/https://github.com/cloudnative-pg/charts/releases/download/cloudnative-pg-v0.28.2/cloudnative-pg-0.28.2.tgz" | tar xz
  > mv cloudnative-pg remote-cloudnative-pg-0.28.2
  > ```
- **离线路径**: `remote-cloudnative-pg-0.28.2/`（禁止修改此目录）

## 本地安装

```bash
# 只安装 operator（不创建数据库实例）
helm upgrade --install cnpg ./remote-cloudnative-pg-0.28.2 \
  -n cnpg-system --create-namespace \
  -f ./values-prod.yaml

# 安装完成后使用 kubectl 创建 Cluster CR
kubectl apply -f ../operator/common/secret.yaml
kubectl apply -f ../operator/standalone/cluster.yaml
```

## 目录说明

| 文件/目录 | 说明 |
|-----------|------|
| `remote-cloudnative-pg-0.28.2/` | 离线 Chart，helm pull 原样保留，禁止修改 |
| `values-prod.yaml` | Operator 资源限制配置 |

## 关键配置

- `crds.create: true` — 自动创建 CRD
- `config.clusterWide: true` — 监控所有命名空间中的 Cluster CR
- Operator 资源: request 100m/128Mi, limit 300m/256Mi

## 升级

```bash
# 1. 下载新版 chart
helm pull cnpg/cloudnative-pg --version <新版> --untar
mv cloudnative-pg remote-cloudnative-pg-<新版>

# 2. 升级 operator
helm upgrade cnpg ./remote-cloudnative-pg-<新版> \
  -n cnpg-system -f ./values-prod.yaml
```

## 卸载

```bash
helm uninstall cnpg -n cnpg-system
```

## 官方文档

<https://cloudnative-pg.io/documentation/current/>
