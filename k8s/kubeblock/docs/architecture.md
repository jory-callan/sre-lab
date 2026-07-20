# 架构详解

> 本文档深入解释 KubeBlocks 数据库集群的架构分层、
> 备份体系的三层解耦设计、以及监控数据链路。

---

## 1. 总览

```
┌──────────────────────────────────────────────────────────────────┐
│                       控制面 (Control Plane)                      │
│                                                                  │
│  ┌─────────────────────────────┐  ┌────────────────────────────┐ │
│  │     KubeBlocks Operator     │  │  VictoriaMetrics Operator   │ │
│  │  (operators ns, v1.0.2)     │  │  (monitoring ns)            │ │
│  │                             │  │                            │ │
│  │  Cluster Controller         │  │  VMAgent / VMAlert         │ │
│  │  Backup Controller          │  │  VMSingle / Grafana        │ │
│  │  Configuration Controller   │  │  AlertManager              │ │
│  └─────────────────────────────┘  └────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
          │                              │
          │ 管理 Cluster CR               │ 通过 VMPodScrape/
          │ + BackupSchedule             │ VMServiceScrape 发现
          ▼                              ▼
┌──────────────────────────────────────────────────────────────────┐
│                      数据面 (Data Plane)                          │
│                                                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                       │
│  │  Redis   │  │  Valkey  │  │  MySQL   │  ← KubeBlocks Cluster  │
│  │ 2+3 Sent │  │ 2+3 Sent │  │ 3 Raft   │    每个独立 namespace  │
│  │ ns:redis │  │ns:valkey │  │ns:mysql  │                       │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘                       │
│       │             │             │                              │
│       │exporter:9121│exporter:9121│exporter:9104                │
│       └─────────────┴─────────────┴───┬──────────────────────────┘
│                                       │
│                        ┌──────────────┴──────────────┐
│                        │  VictoriaMetrics VMSingle    │
│                        │  (monitoring ns)             │
│                        └──────────────┬──────────────┘
│                                       │
│                        ┌──────────────┴──────────────┐
│                        │  Grafana / AlertManager      │
│                        └─────────────────────────────┘
└──────────────────────────────────────────────────────────────────┘
          │
          │ 备份数据流
          ▼
┌──────────────────────────────────────────────────────────────────┐
│                      备份存储层                                   │
│                                                                  │
│  MinIO S3 (minio ns)          ┌─ 桶: kubeblocks-backup          │
│  Tool 模式直传                └─ 路径: /<cluster-id>/<method>/  │
│                                                                  │
│  (可切换: NFS / FTP / AWS S3 / PVC ... 见 backup-storage.md)     │
└──────────────────────────────────────────────────────────────────┘
```

---

## 2. 备份体系：三层解耦

KubeBlocks 的备份体系是典型的三层抽象，这是理解一切备份行为的关键。

### 2.1 架构分层

```
┌─────────────────────────────────────────────────────────────────┐
│  第一层：BackupSchedule（你写的内容）                              │
│                                                                  │
│  用途：定义"什么时候用什么方法备份，保留多久"                        │
│  namespace-scoped，每个 Cluster 独立                              │
│                                                                  │
│  apiVersion: dataprotection.kubeblocks.io/v1alpha1               │
│  kind: BackupSchedule                                            │
│  spec:                                                           │
│    schedules:                                                    │
│      - backupMethod: datafile    # 方法名称（指向第二层）          │
│        cronExpression: 0 3 * * *                                 │
│        enabled: true                                             │
│        retentionPeriod: 7d                                       │
└───────────────────────────┬─────────────────────────────────────┘
                            │ 引用
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  第二层：BackupPolicy（KubeBlocks 自动创建）                       │
│                                                                  │
│  用途：定义"有哪些备份方法可用，每种方法怎么执行"                    │
│  由 KubeBlocks 在创建 Cluster 时自动生成（ownerReferences 绑定）   │
│                                                                  │
│  backupMethods:                                                  │
│    - name: datafile                                              │
│      actionSetName: redis-physical-br    # 指向 ActionSet        │
│      targetVolumes:                       # 备份哪些卷           │
│        volumeMounts: [{mountPath: /data, name: data}]            │
│    - name: aof                                                  │
│      actionSetName: redis-for-pitr                               │
│    - name: volume-snapshot                                       │
│      snapshotVolumes: true              # CSI 快照模式            │
└───────────────────────────┬─────────────────────────────────────┘
                            │ 备份数据写到哪？
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  第三层：BackupRepo（你创建的一次性全局资源）                       │
│                                                                  │
│  用途：定义"备份数据存到哪里"                                      │
│  cluster-scoped，所有 Cluster 共享（is-default-repo 标记）        │
│                                                                  │
│  spec:                                                           │
│    storageProviderRef: minio     # 指向 KubeBlocks 内建的驱动    │
│    accessMethod: Tool            # Tool=进程直传 / Mount=挂载卷  │
│    config:                                                      │
│      bucket: kubeblocks-backup                                   │
│      endpoint: http://minio.minio.svc:80                         │
└───────────────────────────┬─────────────────────────────────────┘
                            │ 模板渲染
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  第四层：StorageProvider（KubeBlocks 内建）                       │
│                                                                  │
│  用途：定义"每种存储的驱动参数模板"                                 │
│  KubeBlocks 安装时自带（minio/s3/ftp/pvc/nfs/oss/...）          │
│                                                                  │
│  datasafedConfigTemplate:                                        │
│    [storage]                                                     │
│    type = s3                                                     │
│    provider = Minio                                              │
│    endpoint = {{ .Parameters.endpoint }}                         │
│    access_key_id = {{ .Parameters.accessKeyId }}                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 为什么这样设计？

这个分层的核心目的是**关注点分离**：

| 层 | 谁关注 | 变更频率 | 例子 |
|----|--------|---------|------|
| BackupSchedule | **应用 owner** | 常变 | "我要加一个凌晨的备份" |
| BackupPolicy | **KubeBlocks 维护者** | 版本升级时变 | "Redis 7.2 升到 7.4，备份脚本变了" |
| BackupRepo | **平台管理员** | 偶尔变 | "公司换存储了，从 MinIO 迁到 S3" |
| StorageProvider | **KubeBlocks 开发者** | 几乎不变 | "新增一个华为 OBS 驱动" |

**你在 backup-enable.yaml 中看不到 MinIO 配置**，因为你不需要关心它。
BackupSchedule 只关心"用什么方法备份"，不关心"存到哪里"。
存储目标是 BackupRepo 层统一管理的。

### 2.3 `backupMethod` 详解

每个 `backupMethod` 是 KubeBlocks 为每种数据库预定义的**备份技术**。
它们不是"全量/增量/差异"的关系，而是**不同的技术路径**：

#### Redis / Valkey

| backupMethod | 底层技术 | 数据内容 | 恢复速度 | 典型大小 | 适用场景 |
|-------------|---------|---------|---------|---------|---------|
| `datafile` | RDB 物理文件 + BR (Backup & Restore) | 压缩后的数据快照 | ⚡ 最快 | 最小 | **日常全量恢复**、克隆环境 |
| `aof` | AOF 日志流式归档 | 增量写操作日志 | 🐢 较慢 + 需回放 | 小 | PITR（恢复到过去任意时间点） |
| `volume-snapshot` | CSI VolumeSnapshot | 整块 PVC 快照 | ⚡ 秒级 | 与 PVC 相同 | 需要存储类支持，整卷克隆 |
| `backup-for-rebuild-instance` | 数据文件复制 | 仅实例重建所需数据 | ⚡ 快 | 小 | KubeBlocks 内部用于故障重建 |

#### ApeCloud MySQL

| backupMethod | 底层技术 | 数据内容 | 恢复速度 | 适用场景 |
|-------------|---------|---------|---------|---------|
| `xtrabackup` | Percona XtraBackup 全量 | 完整 InnoDB 物理备份 | ⚡ 快 | **日常全量恢复** |
| `xtrabackup-inc` | XtraBackup 增量（基于上次全量） | 变更的数据页 | ⚡ 快 | 全量之间的增量补充 |
| `volume-snapshot` | CSI VolumeSnapshot | 整块 PVC 快照 | ⚡ 秒级 | 需要存储类支持 |
| `archive-binlog` | Binlog 持续归档 | Binlog 文件 | 🐢 需回放 | PITR 时间点恢复 |

### 2.4 备份数据流

当一条备份调度被触发时：

```
1. KubeBlocks Backup Controller 创建 Backup CR
2. Backup Controller 启动一个 Job Pod
3. Job Pod 中运行 datasafed 工具
4. datasafed 从 BackupRepo 读取存储配置
5. datasafed 读目标 Pod 的数据（RDB/AOF/XtraBackup 等）
6. datasafed 流式上传到 MinIO S3
   └── 路径: /<cluster-uid>/<component-name>/<backup-name>/
7. 上传完成后，记录 Backup CR 状态为 Completed
```

---

## 3. 监控体系：双模式采集

### 3.1 数据链路

```
Pod (exporter)                        VictoriaMetrics
┌────────────┐  scrape (Pod IP)       ┌────────────┐
│ redis:9121 │ ◄──── VMPodScrape ──── │  VMAgent   │
│ valk:9121  │                        │            │
│ mysql:9104 │                        │ remoteWrite│
└────────────┘                        ▼           │
                                      ┌──────────┐│
┌────────────┐  scrape (Service IP)   │ VMSingle ││
│ redis:9121 │ ◄─ VMServiceScrape ─── │          │◄┘
│ valk:9121  │                       │ ┌────────┐│
│ mysql:9104 │                       │ │ Grafana││
└────────────┘                       │ │ Alert  ││
                                     │ └────────┘│
                                     └───────────┘
```

### 3.2 两种采集模式的差异

| 维度 | VMPodScrape（Pod 级） | VMServiceScrape（Service 级） |
|------|---------------------|------------------------------|
| 发现方式 | 直接匹配 Pod 标签 | 通过 Service 关联到 Endpoint |
| 标签来源 | Pod 标签 | Service 标签 + 可附加 Pod 标签 |
| 与 Prometheus 关系 | 等价于 PodMonitor | **等价于 ServiceMonitor** |
| 适用场景 | 精细控制抓取目标 | 标准 Prometheus 迁移场景 |
| 当前状态 | ✅ 已部署 | ✅ 已部署 |

> 两种模式同时启用、同时工作，互为补充。

### 3.3 告警规则分布

| 规则文件 | 告警数量 | 覆盖的严重级别 | 关键告警 |
|---------|---------|--------------|---------|
| `redis-vmrule-alerts.yaml` | 8 | Critical + Warning | RedisDown, MissingMaster, MemoryHigh, ReplicationBroken |
| `valkey-vmrule-alerts.yaml` | 6 | Critical + Warning | 兼容 Redis 指标格式同上 |
| `mysql-vmrule-alerts.yaml` | 7 | Critical + Warning | MySQLDown, RaftQuorumLost, ReplicationLag, SlowQueries |

所有告警通过 VMAlert → AlertManager 路由 → 通知渠道（邮件/钉钉/Webhook）。

---

## 4. 网络模型

### 4.1 CiliumNetworkPolicy 规则

```
                      ┌──────────┐
                      │  kdebug  │ ◄── 运维调试访问
                      └────┬─────┘
                           │
         ┌─────────────────┼────────────────────┐
         │                 │                     │
         ▼                 ▼                     ▼
   ┌──────────┐     ┌──────────┐     ┌──────────┐
   │  redis   │     │  valkey  │     │  mysql   │
   │ 6379     │     │ 6379     │     │ 3306     │
   │ 26379    │     │ 26379    │     │          │
   ├──────────┤     ├──────────┤     ├──────────┤
   │ 9121(m)  │     │ 9121(m)  │     │ 9104(m)  │
   └────┬─────┘     └────┬─────┘     └────┬─────┘
        │                │                │
        └────────────────┼────────────────┘
                         │
                    ┌────┴─────┐
                    │monitoring│ ◄── Metrics 采集
                    └──────────┘
```

允许的入站来源：同 namespace / `monitoring` (metrics 端口) / `kdebug` (运维调试)

---

## 5. 节点调度策略

### 当前约束

```
可调度节点: agent-1, agent-2  (2 个)
不可调度:    k3s-server-1 (control-plane, NoSchedule)

副本分布：
  Redis data  (2副本): agent-1 ─ agent-2    ✅ 硬反亲和正好
  Valkey data (2副本): agent-1 ─ agent-2    ✅ 硬反亲和正好
  Sentinel    (3副本): 必有 2 个同节点       ⚠️ 软反亲和
  MySQL       (3副本): 必有 2 个同节点       ⚠️ 软反亲和
```

### 未来扩容建议

```bash
# 新增 agent-3 节点后
# 1. 去除节点 taint（如果存在）
kubectl taint nodes agent-3 node-role.kubernetes.io/control-plane:NoSchedule-

# 2. 更新 cluster.yaml 将 preferred 改为 required
#    重新 apply 后 Pod 会重新调度到不同节点
```

---

## 6. 组件版本依赖

| 组件 | 版本 | 来源 |
|------|------|------|
| KubeBlocks Operator | 1.0.2 | helm-chart-kubeblocks-1.0.2.tgz |
| Redis | 7.2.4 | docker.io/apecloud/redis:7.2.4 |
| Valkey | 8.1.8 | docker.io/apecloud/valkey:8.1.8 |
| ApeCloud MySQL | 8.0.30 | docker.io/apecloud/apecloud-mysql-server:8.0.30 |
| VictoriaMetrics Stack | 0.85.9 (Helm) / v1.146.0 (images) | vm helm chart |
| MinIO | latest | minio/minio |
| Cilium | latest (CNI) | k3s 内置 |
| StorageClass | nfs-client | nfs-subdir-external-provisioner |
