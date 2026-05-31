# 03-infra-k8s - Kubernetes 基础设施应用

## 📂 目录结构

```
03-infra-k8s/
├── mysql/
│   ├── dev/
│   │   └── manifests/       # 原生 YAML（先做这个）
│   │   ├── helm/            # Helm Chart（未来添加）
│   │   └── kustomize/       # Kustomize（未来添加）
│   └── prod/
│       └── manifests/
├── postgresql/
│   ├── dev/
│   └── prod/
├── kite/
│   ├── manifests/             # 原生 K8s 清单
│   ├── helm/                  # Helm Chart
│   ├── install.sh             # 安装脚本
│   └── uninstall.sh           # 卸载脚本
└── redis/
    ├── dev/
    └── prod/
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

| 应用 | 说明 |
|------|------|
| [mysql/](./mysql/) | MySQL 数据库 |
| [postgresql/](./postgresql/) | PostgreSQL 数据库 |
| [redis/](./redis/) | Redis 缓存 |
| [kite/](./kite/) | Kubernetes Web UI 管理面板 |
