# ArgoCD GitOps

This directory contains **ArgoCD Application** configurations that enable GitOps for the `sre-lab` repository.

## What is GitOps?

GitOps means **Git is the single source of truth** for Kubernetes cluster state. ArgoCD runs inside the cluster, watches this Git repository, and ensures the cluster matches what's defined here. If someone manually changes the cluster, ArgoCD reverts it back to what's in Git.

```
                 ┌──────────────┐
  git push ─────▶│  sre-lab     │◀──── ArgoCD 检测到变更
                 │  (GitHub)    │─────▶ 自动同步到集群
                 └──────────────┘
```

## Prerequisites

- A Kubernetes cluster (k3s, EKS, GKE, etc.)
- `kubectl` configured with cluster access

## How to Install ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Wait for all pods to be ready:

```bash
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=180s
```

## How to Deploy an Application

### Step 1: Create the ArgoCD Application

```bash
kubectl apply -f argocd/apps/kdebug.yaml
```

### Step 2: Check sync status

```bash
kubectl get applications -n argocd
```

Expected output:

```
NAME     SYNC STATUS   HEALTH STATUS   REVISION
kdebug   Synced        Healthy         4d6cc78
```

### Step 3: Verify the application is running

```bash
kubectl get all -n kdebug
curl http://kdebug.kdebug.svc.cluster.local/ping
```

## Directory Structure

```
argocd/
├── README.md            ← This file
├── project.yaml         ← ArgoCD Project (RBAC, allowed sources)
├── apps/                ← Application definitions
│   └── kdebug.yaml      ← kdebug: deployed from k8s/apps/kdebug/manifests/
└── infra/               ← Infrastructure applications
    └── monitoring.yaml  ← Monitoring stack (to be configured)
```

## How It Works

Each YAML file in `apps/` or `infra/` defines an **ArgoCD Application**:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kdebug
  namespace: argocd
spec:
  source:
    repoURL: 'https://github.com/jory-callan/sre-lab.git'
    targetRevision: main
    path: k8s/apps/kdebug/manifests    # ← Git 里的路径
  destination:
    namespace: kdebug                   # ← 部署到集群的哪个命名空间
    server: 'https://kubernetes.default.svc'
  syncPolicy:
    automated:
      prune: true                       # 删除 Git 里的文件 = 删除集群资源
      selfHeal: true                    # 手动改集群 = 自动改回来
```

### Key Concepts

| Term | Meaning |
|------|---------|
| **Application** | An ArgoCD CR that links a Git path → cluster namespace |
| **Sync** | ArgoCD applies Git state to cluster |
| **Prune** | Delete resources that were removed from Git |
| **Self-heal** | Revert manual cluster changes back to Git state |
| **App-of-Apps** | A root Application that manages child Applications |

## Adding a New Application

1. Create a YAML file in `argocd/apps/` (or `argocd/infra/`)
2. Set `spec.source.path` to the directory in `k8s/` containing your manifests
3. Set `spec.destination.namespace` to the target namespace
4. Commit and push
5. Run `kubectl apply -f argocd/apps/your-app.yaml`

The application will auto-sync on the next ArgoCD reconciliation cycle (~3 minutes). For immediate sync:

```bash
kubectl patch applications -n argocd <app-name> --type merge \
  -p '{"operation":{"sync":{}}}'
```
