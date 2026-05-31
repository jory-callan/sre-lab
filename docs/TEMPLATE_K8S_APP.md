# 应用标准模板（Kubernetes）

这是一个标准的应用目录模板，用于 `infra-k8s/` 和 `apps-k8s/`。

## 📂 目录结构

```
{app-name}/
├── dev/
│   ├── README.md              # ⭐ 方案对比和选择指南
│   ├── install-manifests.sh   # 用 manifests 安装
│   ├── install-helm.sh        # 用 Helm 安装（未来）
│   ├── install-kustomize.sh   # 用 Kustomize 安装（未来）
│   │
│   ├── manifests/             # 方案 1：原生 YAML（先做这个）
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── pvc.yaml
│   │
│   ├── helm/                  # 方案 2：Helm Chart（未来）
│   │
│   └── kustomize/             # 方案 3：Kustomize（未来）
│
└── prod/
    └── (同 dev 结构)
```

---

## 📄 README.md 内容模板

```markdown
# {应用名} - {环境} 环境部署

## 方案对比

| 方案 | 适用场景 | 优点 | 缺点 |
|------|---------|------|------|
| **manifests** | 快速测试、简单部署 | 简单直接，一眼看懂 | 灵活性差 |
| **helm** | 生产级部署、需要定制 | 灵活、版本管理好 | 复杂 |
| **kustomize** | 需要多环境覆盖 | 轻量、不需要额外工具 | 需要学习 |

## 快速开始

### 方案 1：用原生 YAML（推荐）
```bash
./install-manifests.sh
```

### 方案 2：用 Helm（未来）
```bash
./install-helm.sh
```

### 方案 3：用 Kustomize（未来）
```bash
./install-kustomize.sh
```
```
