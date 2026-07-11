# MinIO 交付说明

> 对象存储服务，S3 兼容 API。本文档面向**对接开发者**，说明连接方式、凭证获取、资源规格与使用限制。

---

## 连接方式

| 位置 | 服务 | Endpoint | 协议 |
|------|------|----------|------|
| 集群内部 | S3 API | `http://minio.minio.svc:80` | HTTP（同 namespace 可用 `minio:80`） |
| 集群内部 | Web Console | `http://minio-console.minio.svc:9090` | HTTP |
| 集群外部 | S3 API | `https://minio-api.czw-sre.internal` | HTTPS（Ingress TLS 终结） |
| 集群外部 | Web Console | `https://minio.czw-sre.internal` | HTTPS |

### S3 SDK 配置示例

```python
# Python boto3
s3_client = boto3.client(
    "s3",
    endpoint_url="http://minio.minio.svc:80",       # 集群内；外部用 https://minio-api.czw-sre.internal
    aws_access_key_id="<AK>",
    aws_secret_access_key="<SK>",
    region_name="us-east-1",
    # 内部 HTTP 无需 verify；外部 HTTPS 用 cert-manager CA 或 skip
)
```

```bash
# mc CLI
mc alias set dev http://minio.minio.svc:80 <AK> <SK>
```

> ⚠️ **集群内部连接时请用 HTTP**，TLS 在 Ingress 终结，内部 Service 是明文。

---

## 凭证

### Root 账号

| AK | SK | 策略 | 说明 |
|----|----|------|------|
| `minioadmin` | `minioadmin` | 内置 root（全部权限） | Console 登录、初始化、全局管理，**生产环境必须改密码** |

### 预置服务账号

| AK | SK | 策略 | 权限范围 |
|----|----|------|---------|
| `svc-poweruser` | `ZYz04aZn0xQpzn8l` | `readwrite` | 所有 bucket 读写 |
| `svc-private` | `6u7P3bXODmLRwhm/` | `private-rw` | 仅 `private` bucket 读写 |

### SK 获取命令

```bash
kubectl -n minio get secret svc-poweruser -o jsonpath='{.data.CONSOLE_SECRET_KEY}' | base64 -d
kubectl -n minio get secret svc-private   -o jsonpath='{.data.CONSOLE_SECRET_KEY}' | base64 -d
```

### 新增服务账号

见 [AK.md](AK.md) 方式 1/2/3。

---

## 预置 Bucket

| Bucket | 用途 | 公开访问 |
|--------|------|---------|
| `public` | 公开可读数据（静态资源等） | 是（匿名可读） |
| `private` | 内部数据 | 否（仅 `svc-private` 可读写） |
| `velero` | Velero 集群备份 | 否 |
| `vm-metrics` | VictoriaMetrics 长期指标 | 否 |
| `vm-logs` | VictoriaMetrics Logs | 否 |

---

## 资源规格

### Tenant 规格

| 项 | 值 |
|----|-----|
| 部署模式 | 单节点（1 server） |
| 数据卷 | 4 卷 / 2Gi 每卷 / NFS 后端 |
| 总存储容量 | **8Gi**（2Gi × 4） |
| 纠删码 | **EC:0**（无数据冗余） |
| 存储类 | `nfs-client`（可跨节点迁移） |
| 镜像 | `quay.io/minio/minio:RELEASE.2025-09-07T16-13-09Z` |

### Pod 资源限制

| 资源 | Request | Limit |
|------|---------|-------|
| CPU | 50m | 500m |
| 内存 | 128Mi | 512Mi |

> PVC 用量超过 80% 时 MinIO 会触发只读保护，且 NFS 写延迟会急剧上升。

### 性能上限估算

| 维度 | 上限 | 瓶颈因素 |
|------|------|---------|
| 单文件大小 | 无硬限制（Ingress `proxy-body-size: 0`） | NFS IOPS 与网络带宽 |
| 对象数 | ~1000 万/节点（evict 阈值） | Pod 内存 512Mi |
| 吞吐量 | ~100MB/s（NFS 单流瓶颈） | NFS 后端网络与磁盘 |
| 并发请求 | ~200 并发 | Pod CPU 500m + NFS 单点 |
| Bucket 数 | ~100 | 无硬限制，受管理面性能约束 |

> 以上为**开发/测试环境**估算值。生产环境建议本地 SSD + 多节点分布式 + EC:2+。

---

## 监控

- **指标端点**: `http://minio.minio.svc:80/minio/v2/metrics/cluster`（Prometheus 每 30s 抓取）
- **Grafana**: 监控栈已预置 MinIO 仪表盘（`grafana_dashboard=minio`）
- **关键指标**:
  - `s3_requests_total` — 请求量
  - `s3_errors_total` — 错误率
  - `minio_bucket_usage_object_total` — 对象数量
  - `minio_bucket_usage_total_bytes` — 存储用量

---

## 连接依赖

| 组件 | 用途 | 必需 |
|------|------|------|
| cert-manager (`internal-ca` ClusterIssuer) | Ingress TLS 证书 | 是 |
| nginx-ingress | 外部流量接入 | 是 |
| nfs-client StorageClass | PVC 后端存储 | 是 |

---

## 故障排查

开发对接时常见问题：

| 现象 | 原因 | 解决 |
|------|------|------|
| `AccessDenied` | AK/SK 错误或 policy 不足 | 检查凭证和用户策略（`mc admin user info`） |
| `BucketNotFound` | 桶名不存在 | 确认上表预置 Bucket，新增需改 `tenant.yaml` |
| `Connection refused` | 集群内用了 HTTPS 或端口错 | 内部用 `http://minio.minio.svc:80` |
| 上传超时 | 大文件 + NFS 慢 | 等待重试，或确认 Ingress `proxy-body-size: 0` |
| `readonly` 写入报错 | 磁盘使用率 > 80% | PVC 扩容或清理旧数据 |
