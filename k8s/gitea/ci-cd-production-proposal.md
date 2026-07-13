# CI/CD 流水线 — 生产级方案（提案）

> 基于当前基础设施（Gitea + Nexus + K3s），重构为生产级 GitOps 流水线

## 架构总览

```
开发者 push tag
    │
    ▼
┌─ Gitea Actions ──────────────────────────────────────────────┐
│  act_runner (多副本 HA)                                       │
│  job 容器: 专用 runner 镜像 (预装 docker/kubectl/helm/trivy)  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐    │
│  │ Pipeline: lint → test → build → scan → staging → prod │    │
│  └──────────────────────────────────────────────────────┘    │
└─────────────────────┬────────────────────────────────────────┘
                      │
                      ▼
┌─ Stage 1: Lint & Test ───────────────────────────────────────┐
│  golangci-lint / eslint / pytest                              │
│  go test / jest / pytest --cov                                │
│  → 失败则中止流水线                                           │
└─────────────────────┬────────────────────────────────────────┘
                      │
                      ▼
┌─ Stage 2: Build & Cache ─────────────────────────────────────┐
│  docker buildx build \                                        │
│    --cache-from type=registry,ref=.../cache \                 │
│    --platform linux/amd64,linux/arm64 \                       │
│    --push                                                     │
│  → 多架构镜像 + 远程 layer 缓存                               │
└─────────────────────┬────────────────────────────────────────┘
                      │
                      ▼
┌─ Stage 3: Security Scan ─────────────────────────────────────┐
│  trivy image <image> --severity HIGH,CRITICAL                 │
│  → CRITICAL 漏洞 → 阻断流水线                                 │
│  → HIGH 漏洞 → 告警但不阻断                                    │
└─────────────────────┬────────────────────────────────────────┘
                      │
                      ▼
┌─ Stage 4: GitOps Deploy ─────────────────────────────────────┐
│  PR → gitops 仓库 (manifests/helm)                            │
│  │                                                            │
│  ▼                                                            │
│  ArgoCD 检测到 git 变更                                       │
│  │                                                            │
│  ├── Staging: 自动同步                                        │
│  │    健康检查 + smoke test                                   │
│  │                                                            │
│  └── Production: 需人工审批                                    │
│        ArgoCD UI 或 IM 审批                                    │
│        → 自动同步                                              │
└──────────────────────────────────────────────────────────────┘
```

## 组件对比

| 维度 | 当前方案 | 生产级方案 |
|------|---------|-----------|
| **流水线阶段** | build → deploy | lint → test → build → scan → staging → prod |
| **部署方式** | `kubectl set image` (命令式) | GitOps + ArgoCD (声明式) |
| **镜像构建** | docker build (单架构) | docker buildx (amd64 + arm64) |
| **缓存** | 无 | 远程 registry cache |
| **安全扫描** | 无 | Trivy (CVE 阻断) |
| **环境隔离** | 单命名空间 | dev / staging / prod |
| **回滚** | 手动 kubectl | git revert → ArgoCD 自动回滚 |
| **审批** | 无 | 生产环境人工审批 |
| **通知** | 无 | 飞书/钉钉/企微 webhook |
| **Runner HA** | 单副本 | 多副本 + 自动伸缩 |
| **测试** | 无 | 单元测试 + 集成测试 + smoke test |
| **镜像标签** | 仅 tag | tag + commit SHA + timestamp |
| **Helm 管理** | 无 | Helm Chart 版本化管理 |
| **Artifact 仓库** | Nexus (仅 Docker) | Nexus (Docker + Helm + 通用) |

## 详细设计

### 1. Runner 镜像

预装所有工具，避免每次 workflow 安装：

```dockerfile
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y \
    git docker.io curl jq
# 预装 kubectl + helm + trivy
RUN curl -sLO "https://dl.k8s.io/release/v1.31.0/bin/linux/amd64/kubectl" \
    && chmod +x kubectl && mv kubectl /usr/local/bin/
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
RUN curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh
```

### 2. Workflow (多阶段)

```yaml
name: Production Pipeline

on:
  push:
    tags:
      - 'v*'

env:
  REGISTRY: 192.168.5.103:5001
  PROJECT: admin/webhook2im
  GITOPS_REPO: http://192.168.5.107:30021/admin/gitops-config.git

jobs:
  # ── Stage 1: Lint & Test ──
  lint-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Lint
        run: golangci-lint run ./...
      - name: Unit Test
        run: go test -v -race -coverprofile=coverage.out ./...
      - name: Upload Coverage
        uses: actions/upload-artifact@v4
        with:
          name: coverage
          path: coverage.out

  # ── Stage 2: Build & Push (多架构) ──
  build:
    needs: [lint-test]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Login
        run: echo "${{ secrets.REGISTRYTOKEN }}" | docker login $REGISTRY -u admin --password-stdin
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
      - name: Build and Push
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          platforms: linux/amd64,linux/arm64
          tags: |
            ${{ env.REGISTRY }}/${{ env.PROJECT }}:${{ github.ref_name }}
            ${{ env.REGISTRY }}/${{ env.PROJECT }}:${{ github.sha }}
          cache-from: type=registry,ref=${{ env.REGISTRY }}/${{ env.PROJECT }}:buildcache
          cache-to: type=registry,ref=${{ env.REGISTRY }}/${{ env.PROJECT }}:buildcache,mode=max

  # ── Stage 3: Security Scan ──
  security-scan:
    needs: [build]
    runs-on: ubuntu-latest
    steps:
      - name: Scan Image
        run: |
          trivy image --severity HIGH,CRITICAL \
            --exit-code 1 \
            ${{ env.REGISTRY }}/${{ env.PROJECT }}:${{ github.ref_name }}
      - name: Notify on Vulnerability
        if: failure()
        run: |
          curl -X POST -H "Content-Type: application/json" \
            -d '{"msgtype":"text","text":{"content":"⚠️ 镜像安全扫描失败: ${{ env.PROJECT }}:${{ github.ref_name }}"}}' \
            ${{ secrets.WEBHOOK_URL }}

  # ── Stage 4: Deploy Staging (自动) ──
  deploy-staging:
    needs: [security-scan]
    runs-on: ubuntu-latest
    steps:
      - name: Clone GitOps Repo
        run: |
          git clone --depth 1 $GITOPS_REPO /tmp/gitops
          cd /tmp/gitops
          # 更新 staging 环境镜像版本
          sed -i "s|tag:.*|tag: ${{ github.ref_name }}|" environments/staging/${{ env.PROJECT }}/values.yaml
          git config user.name "ci-bot"
          git config user.email "ci-bot@gitea.local"
          git add .
          git commit -m "chore(${{ env.PROJECT }}): bump staging to ${{ github.ref_name }}"
          git push
      - name: Wait for ArgoCD Sync
        run: |
          # 等待 ArgoCD 自动同步并健康检查
          sleep 30
          kubectl wait --for=condition=Ready pod -l app=${{ env.PROJECT }} -n staging --timeout=120s
      - name: Smoke Test
        run: |
          curl -sf http://staging-${{ env.PROJECT }}.czw-sre.internal/health || exit 1

  # ── Stage 5: Approve & Deploy Production ──
  approve-production:
    needs: [deploy-staging]
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Wait for Approval
        run: echo "等待人工审批..."

  deploy-production:
    needs: [approve-production]
    runs-on: ubuntu-latest
    steps:
      - name: Clone GitOps Repo
        run: |
          git clone --depth 1 $GITOPS_REPO /tmp/gitops
          cd /tmp/gitops
          sed -i "s|tag:.*|tag: ${{ github.ref_name }}|" environments/production/${{ env.PROJECT }}/values.yaml
          git config user.name "ci-bot"
          git config user.email "ci-bot@gitea.local"
          git add .
          git commit -m "chore(${{ env.PROJECT }}): bump production to ${{ github.ref_name }}"
          git push
      - name: Notify Success
        run: |
          curl -X POST -H "Content-Type: application/json" \
            -d '{"msgtype":"text","text":{"content":"✅ 部署成功: ${{ env.PROJECT }}:${{ github.ref_name}} → production"}}' \
            ${{ secrets.WEBHOOK_URL }}
```

### 3. GitOps 仓库结构

```
gitops-config/
├── environments/
│   ├── staging/
│   │   └── webhook2im/
│   │       ├── values.yaml          # 环境特定值
│   │       └── kustomization.yaml
│   └── production/
│       └── webhook2im/
│           ├── values.yaml
│           └── kustomization.yaml
├── charts/
│   └── webhook2im/                  # Helm Chart (版本化)
│       ├── Chart.yaml
│       ├── templates/
│       │   ├── deployment.yaml
│       │   ├── service.yaml
│       │   └── ingress.yaml
│       └── values.yaml
└── applications/
    ├── webhook2im-staging.yaml      # ArgoCD Application
    └── webhook2im-production.yaml
```

### 4. ArgoCD Application 示例

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: webhook2im-production
  namespace: argocd
spec:
  project: default
  source:
    repoURL: http://192.168.5.107:30021/admin/gitops-config.git
    targetBranch: main
    path: environments/production/webhook2im
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
  # 生产环境审批 gate
  syncWindows:
    - kind: deny
      schedule: '* * * * *'
      duration: 1m
      applications:
        - webhook2im-production
      manualSync: true    # 仅允许手动同步
```

### 5. 通知集成

| 事件 | 通知目标 | 内容 |
|------|---------|------|
| Pipeline 启动 | IM | 🚀 webhook2im v1.2.0 开始构建 |
| Lint/Test 失败 | IM | ❌ 测试失败: 详情链接 |
| 安全扫描发现漏洞 | IM + 邮件 | ⚠️ CRITICAL 漏洞 x3 |
| Staging 部署完成 | IM | ✅ Staging 已部署: 访问链接 |
| 等待生产审批 | IM | 🟡 等待审批: 生产部署 |
| 生产部署成功 | IM | ✅ 生产已部署 v1.2.0 |
| 生产部署失败 | IM + 电话告警 | 🔴 生产部署失败! |

### 6. 镜像标签策略

```
v1.2.0              # 语义版本 (用户可读)
v1.2.0-a1b2c3d      # 版本 + commit SHA (可追溯)
v1.2.0-20260713     # 版本 + 日期
sha-a1b2c3d4        # 纯 SHA (GitOps 引用)
latest              # 最新稳定版
buildcache          # 构建缓存 (不部署)
```

## 实施路线图

| 阶段 | 内容 | 预估 |
|------|------|------|
| **Phase 1** | 多阶段 workflow + 测试步骤 | 1 天 |
| **Phase 2** | 构建缓存 + 多架构构建 | 0.5 天 |
| **Phase 3** | Trivy 安全扫描 | 0.5 天 |
| **Phase 4** | Helm Chart + GitOps 仓库 | 1 天 |
| **Phase 5** | ArgoCD 部署 + 环境隔离 | 1 天 |
| **Phase 6** | 审批 gate + 通知集成 | 0.5 天 |
| **Phase 7** | Runner 专用镜像 + 多副本 | 0.5 天 |

## 所需新增组件

| 组件 | 用途 | 来源 |
|------|------|------|
| **ArgoCD** | GitOps 部署引擎 | Helm chart (本地) |
| **Trivy** | 镜像漏洞扫描 | act_runner 预装 |
| **GitOps 仓库** | 声明式配置存储 | Gitea 新建仓库 |
| **Helm Chart** | 应用打包标准化 | 各项目新建 |

## 当前方案 vs 生产方案 成本评估

| 项目 | 当前方案 | 生产方案 |
|------|---------|---------|
| 新增组件 | 0 | ArgoCD (1 Deployment) |
| 额外存储 | 0 | GitOps 仓库 (~10MB) |
| 构建时间 | 3-5 min | 5-8 min (含测试+扫描) |
| 运维复杂度 | 低 | 中 |
| 故障恢复时间 | 手动 10min | Git revert 1min |
| 安全风险 | 高 (无扫描) | 低 |
