# 03-infra-k8s - Kubernetes 基础设施应用

## 📂 目录结构

```
03-infra-k8s/
├── mysql8.4/
│   ├── helm/                  # Helm Chart: ps-operator (remote- + values-prod)
│   ├── operator/              # PerconaServerMySQL CR (standalone/cluster)
│   ├── install.sh             # 安装脚本
│   └── uninstall.sh           # 卸载脚本
├── pg17/
│   ├── helm/                  # Helm Chart: cloudnative-pg (remote- + values-prod)
│   ├── operator/              # CNPG Cluster CR (standalone/ha)
│   ├── install.sh             # 安装脚本
│   └── uninstall.sh           # 卸载脚本
├── kite/
│   ├── manifests/             # 原生 K8s 清单
│   ├── helm/                  # Helm Chart
│   ├── install.sh             # 安装脚本
│   └── uninstall.sh           # 卸载脚本
├── monitoring/
│   ├── helm/                  # Helm Chart (remote- + values-prod)
│   ├── install.sh             # 安装脚本
│   └── uninstall.sh           # 卸载脚本
├── redis/
│   ├── helm/                  # Helm Chart: redis-operator (remote- + values-prod)
│   ├── operator/              # Redis CR 定义 (standalone/sentinel/cluster)
│   ├── install.sh             # 安装脚本
│   └── uninstall.sh           # 卸载脚本
```

---

## 🎯 用途

这一层包含用 Kubernetes 部署的基础设施软件和中间件。

---

## 📖 使用说明

每个应用的每个环境提供多种部署方式（按优先级）：

1. **manifests/**：原生 YAML（简单直接，先做这个）
2. **helm/**：Helm Chart（复杂场景用，未来添加）
3. **kustomize/**：Kustomize（多环境覆盖用，未来添加）

### 快速开始

```bash
# 用原生 YAML 部署 MySQL（开发环境）
cd 03-infra-k8s/mysql/dev
kubectl apply -f manifests/
```

每个环境目录里都有 `README.md` 详细说明各个方案的对比和使用方式。

---

## 📦 应用列表

| 应用 | 说明 | 状态 |
|------|------|------|
| [kite/](./kite/) | Kubernetes Web UI 管理面板 | ✅ 已部署 (NodePort:30001) |
| [monitoring/](./monitoring/) | kube-prometheus-stack 监控栈 | ✅ 已部署 (Grafana:30002) |
| [redis/](./redis/) | Redis 缓存（operator 管理） | ✅ 已部署 (NodePort:30003/30004) |
| [mysql8.4/](./mysql8.4/) | MySQL 8.4（Percona PS Operator） | 📦 待部署 (NodePort:30005) |
| [pg17/](./pg17/) | PostgreSQL 17（CloudNativePG） | 📦 待部署 (NodePort:30006) |
| | | |
| ingress-nginx/ | Ingress Controller | ✅ 已部署 |
| metallb/ | 负载均衡器 | ✅ 已部署 |
