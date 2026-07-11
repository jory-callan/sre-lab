# 目录结构设计文档

> 适用仓库：`gitops-base`
> 创建日期：2026-07-04

---

## 设计动机

随着集群纳管的应用增多，原有的单层 `apps/` 目录将基础设施、Operator、中间件、业务应用混在一起，难以快速定位和维护。

本次重组将原 `apps/` 下的组件按运维属性和访问模式拆分为四个顶级目录。

## 目录分层模型

```
gitops-base/
├── infrastructure/    —— 集群级基础设施，被所有节点和应用依赖
├── middleware/        —— 共享中间件依赖，多业务应用共用
├── operators/         —— Operator 控制器，管理面与数据面分离
├── apps/              —— 业务应用 + 独享依赖，保持扁平
├── lab/               —— 选型测试沙箱，不纳入 ArgoCD
└── argocd/            —— Application CRD，指向上述四目录
```

### 各层定位

| 层 | 内容 | 典型组件 | 谁依赖它 | Namespace |
|----|------|---------|---------|-----------|
| `infrastructure/` | 集群级的平台服务（含共享 namespace） | cert-manager, VictoriaMetrics, namespaces | 所有节点和应用 | 官方推荐 / 见下文 |
| `middleware/` | 被多个业务共享的中间件 | MinIO, PostgreSQL, Redis | 多个 apps/ 下的业务应用 | **middleware**（统一） |
| `operators/` | 以控制器模式运行的管理组件 | minio-operator, cnpg-operator, redis-operator | 管理面，不直接承载业务流量 | **operators**（统一） |
| `apps/` | 业务应用及其独享的中间件/数据库 | gitea, kdebug, kite | 终端用户 | 各自命名 |
| `lab/` | 选型测试沙箱（不下发到集群） | CNPG/Redis 选型对比、chaos-test | 人类开发者 | — |

## Namespace 管理策略

根据 namespace 的归属和共享范围，分为三种管理模式：

| 类型 | namespace | 管理方式 | 说明 |
|------|----------|---------|------|
| **共享** | `operators` / `middleware` | `infrastructure/namespaces/` 统一管理，`sync-wave: 0` 最先部署，`prune: false` 防误删 | 被多个组件共享，统一管控配额和资源 |
| **官方推荐** | `cert-manager` 等 | 各 App 自管（`CreateNamespace: true`） | 保持官方 Helm chart 的 namespace 配置 |
| **业务应用** | 各自命名 | 各 App 自管（`CreateNamespace: true`） | 业务应用独占，生命周期跟随应用 |

所有使用共享 namespace 的 Application 均设 `CreateNamespace: false`，
namespace 只由 `argocd/infrastructure/namespaces/application.yaml` 管理。

## 判断依据

某个组件应该放在哪个目录，按以下优先级判断：

### 1. `operators/` —— 是不是 Operator？

判断标准：

- 以 CRD + Controller 模式运行，管理其他资源？
- 自身不对外提供业务端口？ → **operator**

例外：cert-manager 虽然本质是 Operator，但它的 Helm chart 官方推荐 namespace 为 `cert-manager`，且有 Webhook 资源依赖此 namespace，因此放在 `infrastructure/` 而非 `operators/`。所有其他 Operator 统一使用 `operators` namespace。

### 2. `infrastructure/` —— 是不是集群基础设施？

判断标准：

- 应用层依赖它才能正常工作？
- 没有它，其他层无法运行？ → **infrastructure**

典型场景：监控、日志、备份、CRD 定义。

### 3. `middleware/` —— 是不是共享依赖？

判断标准：

- 两个或以上业务应用需要访问它？
- 数据不随某个业务应用的存亡而存亡？
- 运维策略统一，不需要按业务定制？ → **middleware**

### 4. `apps/` —— 是不是业务应用（或它的独享依赖）？

判断标准：

- 是一个业务应用，或者专为某个业务应用服务的中间件/数据库？
- 只被一个业务访问？
- 生命周期跟随该业务？ → **apps**

## 命名约定

- 目录名全小写，中划线连接
- `operators/` 下的组件统一使用 **`operators`** namespace
- `middleware/` 下的组件统一使用 **`middleware`** namespace
- `infrastructure/` 下的组件使用各自官方推荐的 namespace（如 cert-manager → `cert-manager`）
- `apps/<name>/` 扁平的 `<name>/` 结构，不嵌套子层级（如 `apps/gitea/` 不放 `apps/gitea/postgres/`，而是在 `apps/gitea/` 平铺 YAML）

## 演进原则

1. 新增组件先在 `lab/` 下完成选型测试（选型对比、HA 验证、chaos-test），验证通过后复制到正式目录
2. 共享数据库、中间件放在 `middleware/`
3. 新引入 Operator，放在 `operators/`
4. 引入新业务应用，放在 `apps/`
5. 业务独享的数据库或消息队列，也放在 `apps/<name>/` 下
6. `lab/` 不下发到集群，ArgoCD 不读取此目录

## 迁移记录

2026-07-04 完成首批迁移：

| 原路径 | 新路径 | 依据 |
|--------|--------|------|
| `apps/cert-manager/` | `operators/cert-manager/` | Operator 控制器 |
| `apps/minio-operator/` | `operators/minio-operator/` | Operator 控制器 |
| `apps/minio/` | `middleware/minio/` | 多应用共享的对象存储 |
| `apps/victoria-metrics/` | `infrastructure/victoria-metrics/` | 集群级监控 |
| `apps/victoria-logs/` | `infrastructure/victoria-logs/` | 集群级日志存储 |
| `apps/victoria-logs-collector/` | `infrastructure/victoria-logs-collector/` | 集群级日志采集 |
| `apps/velero/` | `infrastructure/velero/` | 集群级备份 |
| `apps/prometheus-crds/` | `infrastructure/prometheus-crds/` | 集群级 CRD |
| `apps/monitoring/` | `infrastructure/monitoring/` | 集群级数据源配置 |

2026-07-04 引入数据库组件并新增 `lab/` 目录：

| 新增路径 | 说明 |
|---------|------|
| `lab/cnpg/` + `lab/redis/` | 选型测试沙箱，包含选型对比、HA 验证、chaos-test |
| `operators/cnpg-operator/` + `middleware/postgres/` | CloudNativePG 共享实例（1主2从） |
| `operators/redis-operator/` + `middleware/redis/` | Redis Sentinel 共享实例（1主2从+3哨兵） |
| `infrastructure/cnpg-crds/` | CNPG CRD 独立管理（文件过大超 Helm 限制） |

同日清理 `zz_no_use_just_for_archive/`，内容全部迁移到对应位置或删除。

2026-07-04 完成目录和 namespace 统一：

| 变更 | 说明 |
|------|------|
| `operators/cert-manager/` → `infrastructure/cert-manager/` | cert-manager 保留官方 namespace，归入基础设施 |
| `infrastructure/cnpg-crds/` → `operators/cnpg-operator/crds/` | CRD 合并入 cnpg-operator 目录，不再独立 Application |
| `argocd/cnpg-crds/` 删除 | 同上 |
| 三个 Operator namespace 统一 | minio-operator/cnpg-operator/redis-operator → **operators** |
| 三个中间件 namespace 统一 | MinIO/PostgreSQL/Redis → **middleware** |

2026-07-04 引入统一 namespace 管理：

| 新增 | 说明 |
|------|------|
| `infrastructure/namespaces/` | 集中管理 operators + middleware 的 namespace 和 ResourceQuota |
| `argocd/infrastructure/namespaces/application.yaml` | 专属 Application，sync-wave: 0，prune: false |
| 所有共享 namespace 的 App 改为 `CreateNamespace: false` | cnpg-operator、minio-operator、redis-operator、postgres、minio、redis |
