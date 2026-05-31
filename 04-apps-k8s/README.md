# 04-apps-k8s - Kubernetes 业务应用

## 📂 目录结构

```
04-apps-k8s/
└── kite/
    ├── dev/
    │   ├── helm/              # Helm Chart
    │   └── manifests/         # 原生 YAML
    └── prod/
        ├── helm/
        └── manifests/
```

---

## 🎯 用途

这一层包含用 Kubernetes 部署的你的业务应用。

---

## 📖 使用说明

每个应用的每个环境提供多种部署方式。

### 快速开始

```bash
# Helm 部署
cd 04-apps-k8s/kite/dev/helm
helm install kite . -n kite --create-namespace

# 原生 YAML 部署
cd 04-apps-k8s/kite/dev/manifests
kubectl apply -f . -n kite --create-namespace
```

---

## 📦 应用列表

| 应用 | 说明 |
|------|------|
| [kite/](./kite/) | Kite 应用 |
