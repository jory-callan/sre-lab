# MinIO

对象存储服务，基于 MinIO Operator 部署。提供 S3 兼容的对象存储 API，用于持久化文件、备份数据、以及 VictoriaMetrics 的指标存储。

## 架构

- **Operator**: MinIO Operator (`minio.min.io/v2`) 管理 Tenant CRD 的生命周期
- **Tenant**: 单节点，4 卷 PVC（2Gi/卷，NFS 后端），纠删码 EC:0
- **存储类**: `nfs-client` — 可跨节点迁移，适用开发/测试环境
- **访问入口**:
  - S3 API: `minio-api.czw-sre.internal`（Ingress）
  - Web Console: `minio.czw-sre.internal`（Ingress）
- **TLS**: cert-manager `internal-ca` ClusterIssuer，自动签发

## 交付

> 开发对接请直接看 [DELIVERY.md](DELIVERY.md) — 含 Endpoint、凭证、资源规格、上限估算、故障排查。

### 连接方式

| 位置 | 服务 | 地址 | 端口说明 |
|------|------|------|---------|
| 集群外部 (Ingress) | S3 API | `https://minio-api.czw-sre.internal` | TLS 在 Ingress 终结，后端直连 Service |
| 集群外部 (Ingress) | Web Console | `https://minio.czw-sre.internal` | 同上 |
| 集群内部 | S3 API | `http://minio.minio.svc:80` | 无 TLS，同 namespace 可用 `minio:80` |
| 集群内部 | Web Console | `http://minio-console.minio.svc:9090` | 无 TLS，同 namespace 可用 `minio-console:9090` |

> 集群内部使用 S3 SDK 时，endpoint 填 `http://minio.minio.svc:80`，**不用 HTTPS**（TLS 在 Ingress 终结，内部 Service 是明文）。

### 凭证获取

| 账号 | 类型 | 获取方式 |
|------|------|---------|
| `minioadmin` | root | 明文见 `secret.yaml` 的 `config.env` |
| `svc-poweruser` | 服务账号 | `kubectl -n minio get secret svc-poweruser -o jsonpath='{.data.CONSOLE_SECRET_KEY}' \| base64 -d` |
| `svc-private` | 服务账号 | 同上，secret 名为 `svc-private` |

详细账号策略见 [AK.md](AK.md)。

### 监控对接

- **指标**: Prometheus ServiceMonitor 已配置，每 30s 抓取 `https://minio-api.czw-sre.internal/minio/v2/metrics/cluster`
- **Grafana**: 监控栈已预置 MinIO 仪表盘（命名空间 `monitoring`，标签 `grafana_dashboard=minio`）
- **告警**: VMAlert 中可按 `s3_errors_total > rate 1m` 等配置规则

### 依赖组件

| 组件 | 用途 | 必需 |
|------|------|------|
| cert-manager | TLS 证书自动签发（ClusterIssuer `internal-ca`） | 是 |
| nginx-ingress | 外部流量接入 | 是 |
| nfs-client StorageClass | PVC 后端存储 | 是（当前部署） |
| VictoriaMetrics/Prometheus | 指标采集（ServiceMonitor） | 否（跳过告警） |

### 使用限制

| 维度 | 当前状态 | 生产建议 |
|------|---------|---------|
| 高可用 | 单节点，无 HA | 多节点分布式部署 |
| 纠删码 | EC:0（无数据冗余） | EC:2+ |
| 存储后端 | NFS（性能瓶颈） | 本地 SSD |
| 存储容量 | 4 × 2Gi | 100Gi+/卷 |
| TLS | Ingress 终结，内部明文 | 内部 mTLS 或 Service Mesh |

### 日常操作

```bash
# 查看 Pod
kubectl -n minio get pods

# 查看日志
kubectl -n minio logs -l v1.min.io/tenant=minio -c minio

# 重启（滚动更新）
kubectl -n minio rollout restart statefulset minio-pool-0

# 进入容器执行 mc
kubectl -n minio exec deploy/minio-pool-0-0 -c minio -- mc admin info local
```

## 默认凭证

| 用户名 | 角色 |
|--------|------|
| `minioadmin` / `minioadmin` | root 账号（等同于 AWS 的 root user） |

> **生产环境必须修改**：在 `secret.yaml` 中更新 `MINIO_ROOT_PASSWORD`，建议使用 `sops` 或 SealedSecret 加密存储。

预置服务账号及详细管理方式见 [AK.md](AK.md)。

## 预置 Bucket

| Bucket | 用途 |
|--------|------|
| `velero` | Velero 集群备份 |
| `vm-metrics` | VictoriaMetrics 长期指标 |
| `vm-logs` | VictoriaMetrics Logs |
| `public` | 公开可读数据 |
| `private` | 内部数据 |

## 生产级别使用

### 新增 Bucket

编辑 `tenant.yaml` 的 `spec.buckets` 列表添加或删除桶：

```yaml
spec:
  buckets:
    - name: my-new-bucket
      objectLock: false          # 可选，启用对象锁定（不可变存储）
```

**不会删除**已存在的 bucket（从列表中移除不会触发删除）。

### 管理 Bucket 权限（Policy）

MinIO Operator 的 `spec.buckets` **不支持声明式 policy**。设置 bucket 级别权限有以下方式：

| 场景 | 推荐方式 |
|------|---------|
| 设为 Public（匿名可读） | Console → Bucket → Access Policy |
| 自定义 Policy（限制 IP、特定操作） | mc CLI 或 MinIOJob CRD |
| 自动化 GitOps | MinIOJob CRD（见下方） |

### 管理用户和 Access Key

#### 方式 1：`spec.users`（Tenant CRD，AK/SK + consoleAdmin 权限）

在 `tenant.yaml` 中添加 `spec.users`，引用包含凭证的 Secret：

```yaml
spec:
  users:
    - name: user-myapp
```

对应 Secret：

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: user-myapp
type: Opaque
stringData:
  CONSOLE_ACCESS_KEY: myapp-user
  CONSOLE_SECRET_KEY: myapp-secret-password
```

**注意**：通过 `spec.users` 创建的用户自动获得 `consoleAdmin` 策略（Operator 硬编码），无法指定其他权限。创建后可在 Console 中修改。

#### 方式 2：MinIOJob CRD（声明式执行 mc 命令链）

`MinIOJob`（`job.min.io/v1alpha1`）可执行完整的 mc 命令序列，支持创建 Policy、用户、绑定权限：

```yaml
apiVersion: job.min.io/v1alpha1
kind: MinIOJob
metadata:
  name: minio-init
spec:
  serviceAccountName: mc-job-sa
  tenant:
    name: minio
    namespace: minio
  commands:
    # 1. 创建自定义 Policy
    - op: admin/policy/create
      args:
        name: myapp-readwrite
        policy: /configs/policy.json
      volumeMounts:
        - name: policy-config
          mountPath: /configs
      volumes:
        - name: policy-config
          configMap:
            name: myapp-policy
            items:
              - key: policy.json
                path: policy.json
    # 2. 创建用户（AK/SK）
    - name: add-user
      op: admin/user/add
      args:
        user: myappuser
        password: $(PASSWORD)
      env:
        - name: PASSWORD
          valueFrom:
            secretKeyRef:
              name: myapp-password
              key: PASSWORD
    # 3. 将 Policy 绑定到用户
    - op: admin/policy/attach
      dependsOn:
        - add-user
      args:
        policy: myapp-readwrite
        user: myappuser
```

支持的 `op` 操作：`make-bucket`、`admin/user/add`、`admin/user/remove`、`admin/policy/create`、`admin/policy/attach`、`admin/policy/detach` 等。

#### 方式 3：mc CLI（控制台操作）

```bash
mc alias set myminio https://minio-api.czw-sre.internal minioadmin minioadmin
mc policy set public myminio/public

# 创建只读 policy
mc admin policy create myminio myapp-readonly readonly.json

# 创建用户（AK/SK）并绑定 policy
mc admin user add myminio <access-key> <secret-key>
mc admin policy set myminio myapp-readonly user=<access-key>
```

#### 方式 4：Console UI（手动操作）

访问 `https://minio.czw-sre.internal`：
- **Identity → Users → Create User**：创建用户并生成 AK/SK
- **Identity → Policies → Create Policy**：创建自定义 Policy（JSON 编辑器）
- **Users → 选择用户 → Service Accounts**：为该用户生成服务账号

### Policy 编写参考

MinIO Policy 与 AWS IAM 兼容：

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket", "s3:GetObject"],
      "Resource": ["arn:aws:s3:::my-bucket", "arn:aws:s3:::my-bucket/*"]
    }
  ]
}
```

常用 Action：`s3:GetObject`（读）、`s3:PutObject`（写）、`s3:DeleteObject`（删除）、`s3:ListBucket`（列文件）。

### 监控

ServiceMonitor 已配置，Prometheus 每 30s 抓取 `https://minio-api.czw-sre.internal/minio/v2/metrics/cluster`。关键指标：

- `s3_requests_total` — 请求量
- `s3_errors_total` — 错误率
- `minio_bucket_usage_object_total` — 对象数量
- `minio_bucket_usage_total_bytes` — 存储用量

### 备份

建议定期通过 `mc mirror` 或 `rclone` 将关键 bucket 同步到异地存储。

## 常见故障排查

### MinIO Pod 启动失败

**现象**: Pod 不断 CrashLoopBackOff

**检查项**:
1. `kubectl -n minio logs <pod-name>` — 查看具体错误
2. PVC 是否绑定成功：`kubectl -n minio get pvc` — 若 Pending，检查 NFS Client Provisioner 状态
3. Secret 名称是否正确：`spec.configuration.name` 引用的 Secret 必须存在且包含 `config.env` 键
4. 磁盘空间：NFS 后端剩余空间是否充足

### Console 无法登录

**现象**: 访问 `minio.czw-sre.internal` 提示认证失败

**原因**:
- 第一次登录使用 root 凭证（`minioadmin`/`minioadmin`）
- 如果修改了 Secret，需要重启 Pod 才会生效
- Ingress 证书异常：`kubectl -n minio get certificate` 检查证书状态

### 上传/下载超时或 502

**检查项**:
1. Ingress 配置了 `proxy-body-size: 0`（已配置，大文件上传不受 nginx 限制）
2. PVC 是否写满：`kubectl -n minio exec <pod> -- df -h /export`
3. 如果使用 mc 跨网络访问，确认 `MINIO_PROMETHEUS_AUTH_TYPE=public` 以及网络可达
4. 大文件上传时检查 Ingress Controller 的超时设置

### Bucket 创建不生效

- 确认 Secret 中的 root 凭证正确，Operator 用 root 账号调用管理 API
- 观察 Operator 日志：`kubectl -n minio-operator logs -l app=minio-operator`
- Bucket 创建是幂等的，已存在的 bucket 不会报错

### MinIOJob 执行失败

**现象**: MinIOJob 创建后 Pod 处于 Error 状态

**检查项**:
1. `kubectl describe miniojob <name>` — 查看命令执行状态和错误信息
2. ServiceAccount 是否存在且具备权限：`kubectl get serviceaccount mc-job-sa`
3. Tenant 名称和 namespace 必须与 MinIOJob `spec.tenant` 一致
4. 如果 Secret 引用路径不对，Operator 无法获取 root 凭证去执行 mc 命令
5. 命令之间有依赖关系时，确认 `dependsOn` 字段正确指向前置命令的 `name`

### Operator 升级注意事项

MinIO Operator 版本更新会同时更新 Tenant CRD 的 schema。跨大版本升级前查看 [MinIO Operator Release Notes](https://github.com/minio/operator/releases)。大版本升级建议先备份 Tenant 资源定义。

### 性能问题

当前配置（单节点、4×2Gi、NFS、EC:0）适用于开发/测试。生产环境建议：

- 直接挂载本地 SSD 而非 NFS
- 启用纠删码（`EC:2` 或更高）提供数据冗余
- 使用至少 4 节点分布式部署
- 每个卷至少 100Gi+

## 相关链接

- [MinIO Operator 文档](https://min.io/docs/minio/kubernetes/upstream/)
- [MinIO 客户端 mc](https://min.io/docs/minio/linux/reference/minio-mc.html)
- [MinIO Policy 语法](https://min.io/docs/minio/linux/administration/identity-access-management/policy-based-access-control.html)
