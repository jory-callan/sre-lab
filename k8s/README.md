# K8s Deployments

Kubernetes 资源清单，按功能模块组织。

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
