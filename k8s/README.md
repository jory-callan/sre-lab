# K8s Deployments

Kubernetes 资源清单，按功能模块组织。

## 设计思想

- **扁平命名空间布局** — `k8s/<namespace>/`，一个目录 = 一个 K8s 命名空间
- **Operator 与实例分离** — Operator 控制面统一放 `operators/`，实例 CR 放各自业务命名空间
- **自包含** — 每个组件有 `install.sh` + `uninstall.sh` + `README.md`，无跨目录依赖
- **Helm 优先** — 全部用 Helm 部署，无 kustomize / ArgoCD
- **配额管控** — 每个命名空间配 `resourcequota.yaml`（ResourceQuota + LimitRange）
- **无统一入口** — 每个组件独立部署，`bootstrap/` 是唯一的例外（底座依赖链）

## 布局

```
k8s/
├── bootstrap/         底座安装（Cilium / MetalLB / ingress-nginx / cert-manager / NFS）
├── operators/         Operator 控制面（cnpg / redis / minio operator，ns: operators）
├── monitoring/        监控告警（VictoriaMetrics / VictoriaLogs / FluentBit / Grafana，ns: monitoring）
├── postgres/          PostgreSQL 17（CNPG operator，ns: postgres）
├── redis/             Redis 7.4（manifests / helm / operator，ns: redis）
├── minio/             MinIO 对象存储（Operator，ns: minio）
├── mysql/             MySQL（manifests / operator，ns: mysql）
├── gitea/             自托管 Git 服务（ns: gitea）
├── kite/              K8s Web UI（ns: kite）
├── kdebug/            调试工具（ns: kdebug）
├── temporal/          工作流引擎（ns: temporal）
├── velero/            集群备份（ns: velero）
└── lab/               选型测试沙箱
```

## 组件规范

```
component/
├── README.md          架构说明、命令、版本、安装、访问、初始账户\密钥、等说明，简洁为主
├── Deploy.md          主要是本次部署到详情
├── Monitor.md        （可选）可观测性，例如指标采集说明，告警说明，日志说明等内容
├── install.sh         安装脚本
├── uninstall.sh       卸载脚本
├── resourcequota.yaml 命名空间配额（可选）
├── helm/              自定义 Helm chart（自管理服务）
└── operator/          Operator CR（有状态服务）
```

## 账号密码
密码默认采用 xxx@czw123
例如 postgres postgres@czw123 。 mysql root root@czw123

## 版本管理

每个 README 记录精确版本号 — 镜像、Helm chart、Operator。确保可复现部署。
