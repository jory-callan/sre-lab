# CloudNativePG — PostgreSQL Operator 选型与验证

## 为什么选 CloudNativePG？

| 候选方案 | 结论 | 理由 |
|---------|------|------|
| **CloudNativePG (CNPG)** | ✅ **选择** | CNCF Sandbox，纯 CRD 设计，GitOps 友好，内置 barman 备份 |
| Crunchy PGO | ❌ 淘汰 | 功能强但 CRD 复杂，PostgreSQLCluster 有大量嵌套字段，GitOps 不友好 |
| Zalando Operator | ❌ 淘汰 | 维护模式，社区不活跃 |
| KubeBlocks | ❌ 淘汰 | 过于重量级，管理所有数据库，之前用过但已移除 |
| StackGres | ❌ 淘汰 | Sidecar 模式太重，CRD 复杂 |

**核心决策因素：**
- **GitOps 友好度** — CNPG 一个 Cluster CR 定义全部拓扑，Kustomize 直接管理
- **备份内置** — barman-cloud 直接对接 MinIO（S3 兼容），无需额外组件
- **社区活跃** — CNCF Sandbox，CNPG 1.x 已 GA，更新频率高
- **镜像干净** — `ghcr.io/cloudnative-pg/postgresql` 纯 PG 镜像，无 Sidecar

## 生产就绪特性

| 特性 | 说明 |
|------|------|
| **同步复制** | `minSyncReplicas` / `maxSyncReplicas` 控制同步级别 |
| **自动故障切换** | Operator 检测 master 故障 → 选举新 master → 更新 PVC 绑定 |
| **Barman 备份** | 内置 Wal 归档 + 基础备份，支持 S3/MinIO |
| **Point-in-Time Recovery** | 支持恢复到任意时间点 |
| **Read-only 副本** | 通过 `ReplicaCluster` CRD 创建跨集群只读副本 |
| **连接池** | 内置 PgBouncer 集成（通过 Pooler CRD） |
| **声明式 RBAC** | `managed.roles` 和 `managed.databases` 声明式管理用户/库 |
| **Prometheus 集成** | Pod 自动暴露 9187 metrics 端口 |
| **Online Upgrade** | 支持滚动升级 PG 小版本 |
| **拓扑约束** | Pod 反亲和、节点选择器、容忍度完全声明式 |

## 目录说明

```
lab/cnpg/
├── README.md              ← 本文件：选型理由 + 架构决策
├── operator/              ← Operator 安装方式说明
│   └── README.md
├── single/                ← 单实例测试集群
│   ├── cluster.yaml
│   └── quick-start.sh
└── ha/                    ← 生产级 1主2从 HA 集群
    ├── cluster.yaml          ← 3 节点 HA 配置
    ├── secret.yaml           ← MinIO 备份凭据
    ├── monitoring.yaml       ← ServiceMonitor
    ├── app-creds.yaml        ← 业务应用数据库用户
    └── chaos-test.sh         ← 混沌测试脚本
```

## 部署顺序（测试环境）

```bash
# 1. 安装 CRDs（一次性的，Operator 需要）
kubectl apply --server-side -f ../operator/crds/

# 2. 安装 Operator
kubectl apply -k ../operator/

# 3. 单机测试
kubectl apply -f single/cluster.yaml

# 4. 清理单机，上 HA
kubectl delete -f single/cluster.yaml
kubectl apply -k ha/
```

## NFS 注意事项

当前集群使用 NFS 存储。PostgreSQL 依赖 `fsync` 保证数据安全，
NFS 缓存行为可能导致已提交事务在节点宕机时丢失。

**当前方案适用场景：** demo、开发、非关键业务
**生产方案：** 将 `storageClassName` 改为 Longhorn / Local PV / 外部 SAN

## 参考链接

- [官方文档](https://cloudnative-pg.io/docs/)
- [GitHub](https://github.com/cloudnative-pg/cloudnative-pg)
- [备份与恢复](https://cloudnative-pg.io/documentation/1.30/backup_recovery/)
