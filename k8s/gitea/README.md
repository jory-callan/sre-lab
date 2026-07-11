# Gitea — 自托管 Git 服务

Gitea 是轻量级自托管 Git 服务。

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

**存储：** Gitea 的数据（git 仓库、数据库、配置、LFS）全部存储在 NFS 持久卷上，PVC 删除后数据不丢失。

## 前置条件

- [x] ingress-nginx 已安装且 LoadBalancer IP 已分配
- [x] NFS StorageClass (`nfs-client`) 可用
- [x] DNS `gitea.czw-sre.internal → 192.168.5.205` 已配置
- [x] ingress-nginx `externalTrafficPolicy: Local`（客户端 IP 保留）

## 部署

```bash
ssh k3s-server-1
bash /root/bootstrap/install.sh gitea
```

或单独执行：

```bash
bash /root/bootstrap/gitea/install.sh
```

## 首次配置

部署完成后访问 `https://gitea.czw-sre.internal`，会进入安装页面：

| 配置项 | 填写 |
|--------|------|
| 数据库类型 | **SQLite**（内置，无需额外服务） |
| 站点名称 | `Gitea` |
| 站点 URL | `https://gitea.czw-sre.internal` |
| HTTP 端口 | `3000` |
| 管理员账号 | 自行设置（推荐设置，否则后续无法注册） |

> **提示：** 如果不想看到安装页面，可以在 values.yaml 中设置 `INSTALL_LOCK: true` 并预配管理员。

## 验证

```bash
# 检查 Pod 状态
kubectl -n gitea get pods

# 检查 PVC 绑定（NFS 持久化）
kubectl -n gitea get pvc

# 检查 Ingress
kubectl -n gitea get ingress

# 浏览器访问
curl -s https://gitea.czw-sre.internal/api/healthz
# 预期: {"status":"pass"}

# 创建测试仓库
# 浏览器登录 → 右上角 + → New Repository
# 本地测试 clone:
#   git clone https://gitea.czw-sre.internal/<user>/<repo>.git
```

## 配置说明

### 核心参数 (gitea-values.yaml)

| 参数 | 默认值 | 说明 |
|------|--------|------|
| image.tag | 1.26.4 | Gitea 版本 |
| persistence.size | 10Gi | NFS 持久卷大小 |
| persistence.storageClass | nfs-client | 使用 NFS (RWX) |
| ingress.hosts[0].host | gitea.czw-sre.internal | 域名 |
| gitea.config.database.DB_TYPE | sqlite3 | 数据库类型 |
| resources.requests.memory | 256Mi | 内存请求 |
| resources.limits.memory | 512Mi | 内存上限 |

### 客户端 IP 保留

配置了 `externalTrafficPolicy: Local` + Gitea 信任代理头，确保：

- ingress-nginx 日志中记录真实客户端 IP
- Gitea 审计日志中记录真实来源
- 不需要额外配置 `REVERSE_PROXY_LIMIT`

### SSH 访问

默认 SSH 端口（22）被 k3s 节点占用，Gitea 的 SSH 服务通过 NodePort 暴露：

```bash
# 查看分配的 NodePort
kubectl -n gitea get svc gitea-ssh

# 在 Gitea 设置中将 SSH 克隆 URL 改为
# ssh://git@192.168.5.205:30022/<user>/<repo>.git
```

或者使用 HTTP(S) clone（推荐）：

```bash
git clone https://gitea.czw-sre.internal/<user>/<repo>.git
```

## 清理

```bash
# 卸载 Gitea
helm uninstall gitea -n gitea

# 清理 PVC（删除后将丢失所有数据）
kubectl delete pvc -n gitea --all

# 清理命名空间
kubectl delete namespace gitea
```

## 注意事项

1. **SQLite 适合小团队** — 50 人以上建议改用 PostgreSQL（需启用 postgresql 子图表）
2. **NFS 性能** — git 操作以小文件 IO 为主，NFS 表现可接受。大量 clone/push 时建议升级到 Longhorn
3. **HTTPS** — 目前 ingress 未配 TLS，如需 HTTPS 需安装 cert-manager 并配置 TLS secret
4. **首次安装页面** — `INSTALL_LOCK: false` 时会显示安装页面，需手动配置
5. **内存** — SQLite 模式下 Gitea 使用内存约 200-400MB，512MB 限制足够

## 故障排查

| 现象 | 可能原因 | 解决 |
|------|---------|------|
| Pod CrashLoopBackOff | PVC 未绑定或权限错误 | 检查 `kubectl -n gitea describe pvc` |
| 502 Bad Gateway | Gitea 启动慢，ingress 超时 | 等待 1-2 分钟后重试 |
| 健康检查失败 | 数据库未初始化 | `kubectl -n gitea logs deploy/gitea` |
| 无法 push 大文件 (>100MB) | ingress-nginx 限制 | 修改 values.yaml 中 `proxy-body-size` |
| 克隆速度慢 | NFS IO 延迟 | 检查 NFS server 节点负载 |
