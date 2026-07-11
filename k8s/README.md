# K8s Deployments

Kubernetes 资源清单，按功能模块组织。

## 布局

```
k8s/
├── bootstrap/         底座安装（Cilium / MetalLB / ingress-nginx / cert-manager / NFS）
├── apps/              应用层（Gitea / Kite / kdebug / temporal / velero）
├── middleware/        共享中间件（MinIO / PostgreSQL / Redis）
├── operators/         Operator 控制器（cnpg / minio / redis）
├── monitoring/       监控告警（VictoriaMetrics / VictoriaLogs / FluentBit / Grafana）
├── databases/        数据库部署（MySQL / PostgreSQL / Redis）
├── ingress/          入口网关（ingress-nginx / MetalLB）
├── storage/          存储相关（NFS）
└── lab/              选型测试沙箱
```

## 组件规范

每个组件遵循以下模式：

```
component/
├── README.md          架构说明、命令、版本
├── install.sh         安装脚本
├── uninstall.sh       卸载脚本
├── manifests/         原始 YAML（简单服务）
├── helm/              自定义 Helm chart（自管理服务）
└── operator/          Operator CR（有状态服务）
```

## 版本管理

每个 README 记录精确版本号 — 镜像、Helm chart、Operator。确保可复现部署。
