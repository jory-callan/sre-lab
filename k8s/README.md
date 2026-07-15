# K8s Deployments — SRE Lab

Kubernetes 资源清单。用于个人实验环境（单机 k3s + KubeSphere），以**可复现、可追溯、可交付**为原则组织。

---

## 设计思想

- **Helm 优先** — 全量采用 Helm 部署，无 kustomize / ArgoCD。Helm chart 统一管理，`chart/` 目录存源码，`version-xxx` 文件名即版本号。
- **目录即实例，平铺展开** — 每个实例一个目录，目录内全平铺，`<前缀>-` 区分功能，不建子文件夹。
- **实例不仅是一个 YAML，而是一个可交付单元** — 每个实例目录包含 `部署.md`（部署说明）、`交付.md`（交付说明）、`README.md`（实例说明）、`install.sh`、`uninstall.sh`。
- **管理与运行时解耦** — 目录组织按管理视角（谁和谁一起维护），K8s namespace 按运行时视角。两者独立，不强制对应。
- **Operator 运行时统一归 `operators` namespace** — 所有 operator 部署到 `operators` namespace，统一监控、统一管控。
- **谁消费谁配置** — 外部依赖（桶、用户、凭证）由消费者安装时创建，提供方只装自身。
- **资源配额注释即文档** — `values.yaml` 中 `resources` 用注释标生产推荐值，当前环境只配 `limits` 且按最低要求。
- **无统一入口** — 每个组件独立部署，`bootstrap/` 是唯一的例外（底座依赖链）。

---

## 布局

```
k8s/
├── bootstrap/          底座 — 集群基础设施（安装即用，基本不动）
│   ├── cert-manager/
│   ├── cilium/
│   ├── ingress-nginx/
│   ├── longhorn/
│   ├── metallb/
│   ├── monitoring/     可观测性栈（独立测试多种方案）
│   └── nfs-storageclass/
├── kubeblock/          新派中间件管理家族（KubeBlocks + addon 分组实例）
│   ├── operator/        KubeBlocks operator 本体
│   ├── chart/           Helm chart 源码
│   ├── common/          共享资源
│   ├── redis/           按 addon 引擎分组，实例用 <prefix>-<name>/
│   │   └── cr-auth/     KubeBlocks 管理的 Redis 实例
│   └── apecloud-mysql/
│       └── cr-default/  KubeBlocks 管理的 ApeCloud MySQL 实例
├── middleware/          传统中间件产品
│   ├── dolphinscheduler/
│   ├── gitea/
│   ├── minio/
│   ├── mysql/
│   ├── postgres/
│   ├── redis/
│   ├── temporal/
│   └── velero/
├── app/                自研应用
│   ├── kite/
│   └── kdebug/
├── monitoring/         （预留，曾作为独立目录，现归入 bootstrap/）
└── lab/                垃圾桶 / 实验沙箱 / 备份 — 不做重组，不做约束，随意放
```

---

## 目录约定 — 通用模式

每个 workload 内部统一遵循以下结构：

```
<workload>/
├── operator/                     特殊保留名 — operator 安装卸载
│                                 无论用 Helm 还是 YAML，此目录只负责 operator 生命周期
│   ├── install.sh                helm install｜kubectl apply
│   ├── uninstall.sh              helm uninstall｜kubectl delete
│   ├── values.yaml               operator 专用 values
│   └── README.md
├── chart/                        特殊保留名 — Helm chart 源码
│                                 官方的就存官方源码，自写的就存自写源码，统一管理
│   ├── Chart.yaml
│   ├── values.yaml               chart 默认 values
│   ├── templates/
│   └── version-xxx               文件名即版本号，例如 version-0.28.2
├── common/                       保留名 — 共享资源（镜像构建、全局 dashboard、跨实例配置）
│   ├── custom-image/
│   ├── dashboard/
│   └── ...
├── <env>-<instance>/             实例目录，0~N 个
│                                 环境前缀 + 实例名，例如 test-base、prod-ha、test-redis-auth
│   ├── values.yaml               实例专属 values（覆盖 chart 默认值）
│   ├── 部署.md                   部署说明（怎么装、步骤、依赖先决条件）
│   ├── 交付.md                   交付说明（怎么用、访问方式、初始账号、注意事项）
│   ├── README.md                 实例说明
│   ├── install.sh                helm upgrade --install 幂等安装
│   └── uninstall.sh              helm uninstall 卸载
└── resourcequota.yaml            命名空间配额（可选，namespace 级配置放根目录）
```

### 前缀命名规范

实例目录内所有文件平铺，用前缀区分功能：

| 前缀 | 用途 | 示例 |
|------|------|------|
| `cr-` | Operator 管理的自定义资源 | `cr-cluster.yaml`、`cr-pooler.yaml` |
| `dep-` | 外部依赖资源 | `dep-minio-pg-s3-creds.yaml` |
| `alert-` | 告警规则 | `alert-cnpg-rules.yaml` |
| `service-` | Service / Ingress | `service-external.yaml` |
| `config-` | ConfigMap | `config-app.yaml` |
| `secret-` | Secret | `secret-db.yaml` |

> **关键约定：`cr-` 前缀 = operator 管理**。看到 `cr-` 就知道这是由某个 operator 定义的自定义资源，一眼识别工具归属。

### 实例命名规范

`<环境>-<实例名>`，例如：

| 命名 | 说明 |
|------|------|
| `test-base` | 测试环境，基础实例 |
| `test-single` | 测试环境，单实例 |
| `test-redis-auth` | 测试环境，Redis 认证实例 |
| `prod-ha` | 生产环境，高可用实例 |
| `prod-dr` | 生产环境，灾备实例 |
| `prod-base` | 生产环境，基础实例 |

环境用前缀，不用目录隔开。这样 `ls <workload>/` 一眼看完所有实例，跨环境对比也方便。

---

## 脚本约定 — install.sh / uninstall.sh

所有 `install.sh` 遵循统一模板，只改顶部配置区：

```bash
#!/bin/bash
# install.sh — <实例说明>
# Usage: bash install.sh [install|uninstall|purge]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== 配置区（每个实例改这 4 个变量） =====
NAME="<helm-release-name>"           # Helm release name
NAMESPACE="<target-namespace>"        # 目标 namespace
CHART="$SCRIPT_DIR/../chart"          # chart 路径（也可是 tgz 路径）
VALUES="$SCRIPT_DIR/values.yaml"      # 实例 values
# ===========================================

install() {
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  # 标记 Helm ownership，使 chart 中的 namespace.yaml 可以接管
  kubectl label namespace "$NAMESPACE" app.kubernetes.io/managed-by=Helm --overwrite 2>/dev/null || true
  kubectl annotate namespace "$NAMESPACE" meta.helm.sh/release-name="$NAME" --overwrite 2>/dev/null || true
  kubectl annotate namespace "$NAMESPACE" meta.helm.sh/release-namespace="$NAMESPACE" --overwrite 2>/dev/null || true
  helm upgrade --install "$NAME" "$CHART" \
    --namespace "$NAMESPACE" \
    --values "$VALUES" \
    --timeout 5m --wait
}

uninstall() {
  # 卸载服务，保留 PVC / PV / 数据
  helm uninstall "$NAME" --namespace "$NAMESPACE"
}

purge() {
  # 完全卸载干净
  helm uninstall "$NAME" --namespace "$NAMESPACE" 2>/dev/null || true
  kubectl delete namespace "$NAMESPACE" --ignore-not-found
}

case "${1:-install}" in
  install) install ;;
  uninstall) uninstall ;;
  purge) purge ;;
  *) echo "Usage: $0 [install|uninstall|purge]"; exit 1 ;;
esac
```

设计要点：

| 决定 | 原因 |
|------|------|
| 一个文件三个参数 | 统一入口，省文件，三种模式一目了然 |
| `install` — 部署 | `helm upgrade --install` 幂等，重复执行安全 |
| `uninstall` — 卸载保留数据 | 仅 `helm uninstall`，PVC / 命名空间不动 |
| `purge` — 完全卸载 | `helm uninstall` + `delete namespace`，数据一并清理 |
| 4 变量顶部配置区 | 所有实例脚本长得一样，一目了然 |
| `set -euo pipefail` | 防止静默失败 |
| `--timeout 5m --wait` | 默认等部署完成 |

**operator/install.sh 同理**，区别是 CHART 指向 tgz 或 repo 路径：

```bash
NAME="cnpg"
NAMESPACE="operators"       # 所有 operator 统一部署到 operators namespace
CHART="$SCRIPT_DIR/cloudnative-pg-0.28.2.tgz"
VALUES="$SCRIPT_DIR/values.yaml"
```

---

## 资源约定 — resources 配置

`values.yaml` 中 resources 块的标准写法：

```yaml
resources:
  # ──────────────────────────────────────────
  # 生产推荐值:
  #   requests:
  #     cpu: 500m
  #     memory: 256Mi
  #     ephemeral-storage: 100Mi
  #   limits:
  #     cpu: 1000m
  #     memory: 512Mi
  #     ephemeral-storage: 200Mi
  # ──────────────────────────────────────────
  # 当前环境最低配置（仅 limits，不配 requests，不配 ephemeral-storage）:
  limits:
    cpu: 500m
    memory: 128Mi
```

规则：

| # | 规则 |
|---|------|
| 1 | 注释里写完整块（requests + limits + ephemeral-storage），标 "生产推荐值" |
| 2 | 实际只配 `limits`，不配 `requests` |
| 3 | 实际不配 `ephemeral-storage`（兼容性考虑） |
| 4 | 数值按 lab 环境最低能跑的来 |

---

## 账号密码约定

密码默认采用 `xxx@czw123` 格式。

例如：

| 服务 | 账号 | 密码 |
|------|------|------|
| PostgreSQL | postgres | postgres@czw123 |
| MySQL | root | root@czw123 |
| MinIO | minio | minio@czw123 |

---

## 版本管理

- 每个 `README.md` 记录精确版本号（镜像 / Helm chart / Operator）
- chart 版本用 `chart/version-xxx` 文件标识，文件名即版本号
- 确保可复现部署，不依赖 "latest"

---

## 个人风格说明

对维护者自己说的话：

- **Git 提交规范**：`type(scope): subject`，注释尽量详细。每次修改后 commit。
- **国内环境**：GitHub 拉取加 `https://gh-proxy.com/` 前缀，搜索用 Bing。
- **判断先行**：给出专业判断后再列方案，不搞选择题大全。
- **不内卷**：实例之间允许重复，不搞符号链接 / 公共引用。每个实例自包含。
- **lab 优先**：新方案先在 `lab/` 实验，验证通过再正式接入。
- **不做过度抽象**：`operator/`、`chart/`、`common/` 是少数保留名，除此之外全是实例目录。
