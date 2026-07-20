# KubeBlocks 数据库集群

> 基于 KubeBlocks Operator 的统一数据库管理平台。
> 所有配置、部署脚本、运维文档统一纳入 Git 管理。

---

## 架构总览

```
┌──────────────────────────────────────────────────────┐
│                   KubeBlocks Operator                 │
│                   (operators ns, v1.0.2)              │
└──┬────────┬────────┬────────┬────────┬────────┬──────┘
   │        │        │        │        │        │
   ▼        ▼        ▼        ▼        ▼        ▼
┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐
│Redis │ │  RDB │ │Valkey│ │VALKEY│ │MySQL │ │MySQL │
│ data │ │ Sent │ │ data │ │ Sent │ │ Raft │ │ ......│
│ 2rep │ │ 3rep │ │ 2rep │ │ 3rep │ │ 3rep │ │ more │
└─┬────┘ └─┬────┘ └─┬────┘ └─┬────┘ └─┬────┘ └──────┘
  │        │        │        │        │
  └────────┴────────┴────────┴────────┘
           │           │           │
           ▼           ▼           ▼
    ┌──────────────────────────────┐
    │    基础设施层 (Infra)         │
    │  NFS 存储  │  VictoriaMetrics │
    │  Cilium CNI │  Grafana       │
    │  MinIO S3  │  AlertManager   │
    └──────────────────────────────┘
```

### 备份体系（三层解耦）

```
BackupSchedule          ← 你调度什么、何时做、保留多久
     │
BackupPolicy            ← KubeBlocks 自动创建（定义可用的备份方法）
     │
BackupRepo (cluster)    ← 全局存储目标定义（MinIO / NFS / S3 / FTP...）
     │
StorageProvider (built-in) ← KubeBlocks 内建存储驱动
```

---

## 实例一览

| 实例 | Namespace | 类型 | 版本 | 副本 | 定位 |
|------|-----------|------|------|------|------|
| **Redis** | `redis` | Replication | 7.2.4 | 2 + 3 Sentinel | 缓存/会话存储 |
| **Valkey** | `valkey` | Replication-8 | 8.1.8 | 2 + 3 Sentinel | Redis 替代/兼容 |
| **ApeCloud MySQL** | `mysql` | Raft Consensus | 8.0.30 | 3 | 关系型数据库 |

### 节点分布

```
k3s-server-1  (control-plane, NoSchedule taint)
  ├── agent-1  (可调度, 5C/22G)
  └── agent-2  (可调度, 5C/22G)
```

> ⚠️ 仅 2 个 agent 节点，3 副本组件（Sentinel/MySQL）无法硬反亲和，使用软约束。

---

## 目录结构

```
kubeblock/
├── README.md                   ← 本文档（入口 + 架构 + 快速启动）
├── chart/                      版本标记
├── operator/                   KubeBlocks Operator 安装（helm chart + CRD）
│   ├── install.sh / uninstall.sh
│   └── values.yaml / crd/
├── common/                     全局共享配置
│   ├── backuprepo/              备份仓库（BackupRepo + 凭证）
│   ├── pdb/                     PodDisruptionBudget
│   ├── network-policy/          CiliumNetworkPolicy
│   └── grafana/                 Grafana Dashboard ConfigMaps
├── docs/                       详细文档
│   ├── architecture.md           → 架构详解：备份三层解耦、监控链路
│   ├── backup-storage.md         → 备份存储后端切换指南
│   ├── disaster-recovery.md      → 故障模拟与恢复演练
│   └── production-ready.md       → 运维手册 & 操作参考
├── redis/test-default/          Redis 实例
│   ├── cluster.yaml / config-instance.yaml
│   ├── vmpodscrape.yaml / vmservicescrape.yaml / vmrule-alerts.yaml
│   ├── backup-enable.yaml / restore.yaml
│   └── install.sh / 部署.md / 交付.md / config.md
├── valkey/test-default/         Valkey 实例（结构同上）
└── apecloud-mysql/test-default/ ApeCloud MySQL 实例（结构同上）
```

---

## 快速启动

```bash
# 1. 安装 KubeBlocks Operator
cd operator && bash install.sh && cd -

# 2. 创建备份存储仓库（一次性）
kubectl apply -f common/backuprepo/credential-secret.yaml
kubectl apply -f common/backuprepo/backuprepo.yaml

# 3. 部署数据库实例
kubectl apply -f redis/test-default/cluster.yaml
kubectl apply -f valkey/test-default/cluster.yaml
kubectl apply -f apecloud-mysql/test-default/cluster.yaml

# 4. 等待集群就绪
kubectl get cluster -A -w

# 5. 部署高可用 & 安全
kubectl apply -f common/pdb/
kubectl apply -f common/network-policy/

# 6. 接入监控
kubectl apply -f common/grafana/
kubectl apply -f redis/test-default/vmpodscrape.yaml
kubectl apply -f redis/test-default/vmservicescrape.yaml
kubectl apply -f redis/test-default/vmrule-alerts.yaml
# ... 同理 valkey / mysql

# 7. 启用备份调度
kubectl apply -f redis/test-default/backup-enable.yaml
# ... 同理 valkey / mysql
```

### 卸载 / 清理

各实例目录下的 `install.sh` 支持三个命令：
```bash
bash install.sh uninstall   # 仅删除 Cluster CR（保留数据 PVC）
bash install.sh purge       # 删除 Cluster + PVC + 整个 namespace
```
Operator 卸载：`cd operator && bash uninstall.sh`

---

## 生产就绪清单

| 领域 | 状态 | 配置位置 |
|------|------|---------|
| ✅ 备份策略 | 每日全量 + 每6h增量 → MinIO S3 | `common/backuprepo/`, `*/backup-enable.yaml` |
| ✅ 监控采集 | VMPodScrape + VMServiceScrape 双模式 | `*/vmpodscrape.yaml`, `*/vmservicescrape.yaml` |
| ✅ 告警规则 | 宕机/复制中断/内存/Quorum... | `*/vmrule-alerts.yaml` |
| ✅ Grafana 仪表盘 | Redis + MySQL 已导入 | `common/grafana/` |
| ✅ PodDisruptionBudget | 5 个 PDB 覆盖所有组件 | `common/pdb/` |
| ✅ 节点拓扑分布 | 反亲和调度 | 各 `cluster.yaml` |
| ✅ 网络隔离 | CiliumNetworkPolicy Ingress+Egress | `common/network-policy/` |
| ✅ 运维文档 | 架构/备份切换/容灾演练/运维手册 | `docs/` |

---

## 已知限制 & 风险

| 限制 | 影响 | 缓解措施 |
|------|------|---------|
| 仅 2 agent 节点 | 3 副本组件无法硬反亲和 | 使用软约束 + 文档标注 |
| NFS 不支持 VolumeSnapshot | 无法使用 CSI 快照备份 | 使用 datafile/xtrabackup 工具备份 |
| control-plane 有 NoSchedule | 不可用于调度数据 Pod | 扩容 agent 节点即可解决 |

---

## 参考链接

- [KubeBlocks 官方文档](https://kubeblocks.io/docs/)
- [官方 Addon 示例](https://github.com/apecloud/kubeblocks-addons/tree/main/examples)
- [备份架构详解](docs/architecture.md)
- [备份存储切换指南](docs/backup-storage.md)
- [故障恢复演练](docs/disaster-recovery.md)
- [运维手册](docs/production-ready.md)
