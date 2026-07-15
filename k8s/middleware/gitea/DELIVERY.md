# Gitea 交付详情

## 架构

```
外网用户
    │ DNS: gitea.czw-sre.internal
    ▼
MetalLB (192.168.5.205)
    │
    ▼
ingress-nginx ── X-Forwarded-For 透传客户端 IP
    │
    ▼
Gitea Service (ClusterIP:3000)
    │
    ├── Gitea Pod (SQLite)
    │       └── /data → PVC (nfs-client, 10Gi, RWX)
    │
    └── SSH Service (NodePort:30022)
```

## 存储

- **PVC:** 10Gi, NFS (`nfs-client`, RWX)
- **存储内容:** git 仓库、SQLite 数据库、配置、LFS 文件
- **数据安全:** PVC 删除后数据不丢失（NFS 后端）
- **路径:** `/data/gitea.db`（SQLite） + `/data/git/repositories/`（仓库）

## SSH 访问

k3s 节点占用 22 端口，Gitea SSH 通过 NodePort 30022 暴露：

```bash
# 查看 NodePort
kubectl -n gitea get svc gitea-ssh

# 克隆示例（node-ip 替换为任意集群节点 IP）
git clone ssh://git@<node-ip>:30022/<user>/<repo>.git
```

## 指标采集

Gitea 已开启 `/metrics` 端点，VMAgent 自动发现并采集。

| 指标路径 | 说明 |
|---------|------|
| `https://gitea.czw-sre.internal/metrics` | Gitea 运行时指标 |
| `kubectl -n gitea port-forward svc/gitea-http 3000:3000` | 本地查看 |

如需在 Grafana 查看，导入 [Gitea 官方 Dashboard](https://grafana.com/grafana/dashboards/)（ID: 未发布，需自行制作）。

## 管理员

| 账号 | 初始密码 | 说明 |
|------|---------|------|
| `admin` | `Admin@czw123` | 预配置，安装后直接使用 |

> 首次登录后建议修改密码。

## 首次配置（已锁定）

安装页面已通过 `INSTALL_LOCK: true` 锁定，无需手动初始化。如果需重新配置：

```bash
# 1. 修改 values.yaml 中 INSTALL_LOCK: false
# 2. 升级
helm upgrade gitea gitea-charts/gitea -n gitea -f values.yaml
# 3. 访问 https://gitea.czw-sre.internal 重新配置
```

## 配置说明

### 核心参数 (values.yaml)

| 参数 | 当前值 | 说明 |
|------|--------|------|
| `image.tag` | `1.26.4` | Gitea 版本 |
| `persistence.size` | `10Gi` | NFS 持久卷大小 |
| `persistence.storageClass` | `nfs-client` | 使用 NFS (RWX) |
| `ingress.hosts[0].host` | `gitea.czw-sre.internal` | 域名 |
| `gitea.config.database.DB_TYPE` | `sqlite3` | 数据库类型 |
| `gitea.admin.username` | `admin` | 预配置管理员 |
| `gitea.config.security.INSTALL_LOCK` | `true` | 锁定安装页面 |
| `gitea.config.metrics.ENABLED` | `true` | 开启指标端点 |
| `resources.requests.memory` | `256Mi` | 内存请求 |
| `resources.limits.memory` | `512Mi` | 内存上限 |

## 访问方式

| 方式 | 地址 | 用途 |
|------|------|------|
| Web | `https://gitea.czw-sre.internal` | 浏览器访问 |
| Git HTTPS | `https://gitea.czw-sre.internal/<user>/<repo>.git` | 日常 clone |
| Git SSH | `ssh://git@<node-ip>:30022/<user>/<repo>.git` | SSH 推送 |
| HTTP NodePort | `<node-ip>:30021` | 无 DNS 或 Ingress 调试 |
| SSH NodePort | `<node-ip>:30022` | 无 DNS 或 Ingress 调试 |
| 本地转发 | `kubectl -n gitea port-forward svc/gitea-http 3000:3000` | 本地调试 |

### 客户端 IP 保留

ingress-nginx `externalTrafficPolicy: Local` + Gitea 信任代理头，确保审计日志记录真实客户端 IP。

### HTTPS

默认走 HTTP，如需 HTTPS（需 cert-manager）：

```yaml
ingress:
  annotations:
    cert-manager.io/cluster-issuer: internal-ca
  tls:
    - hosts:
        - gitea.czw-sre.internal
      secretName: gitea-tls
```

## 运维

### 备份

Gitea 数据全部在 PVC 上，直接备份 NFS 后端即可：

```bash
# 或通过 Gitea 内置 dump
kubectl -n gitea exec deploy/gitea -- /bin/su - git -c '/usr/local/bin/gitea dump -c /data/gitea/conf/app.ini'
```

### 升级

```bash
# 修改 values.yaml 中 image.tag
helm upgrade gitea gitea-charts/gitea -n gitea -f values.yaml --wait
```

### 扩容

```bash
# SQLite 不支持多副本。如需 HA，先切到 PostgreSQL：
# 1. 安装 postgresql 子图表（修改 values.yaml 中 postgresql.enabled: true）
# 2. 设置 gitea.config.database.DB_TYPE: postgres
# 3. 扩容 replicaCount
helm upgrade gitea gitea-charts/gitea -n gitea -f values.yaml --wait
```

## 注意事项

1. **SQLite 适合小团队** — 50 人以上建议改用 PostgreSQL
2. **NFS 性能** — git 操作以小文件 IO 为主，大量 clone/push 建议升级 Longhorn
3. **内存** — SQLite 模式下 Gitea 使用内存约 200-400MB，512MB 限制足够
4. **多副本** — SQLite 不支持多副本，如需 HA 必须切 PostgreSQL

## 管理 Access Token
新增一个token  9e870c1e368ec0c430b113095ff82dc147acf130