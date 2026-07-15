# CI/CD 流水线

> 引擎: Gitea Actions + Nexus 镜像仓库 | 风格: 类 GitHub Actions

## 架构

```
开发者 push tag v*
    │
    ▼
Gitea Actions (act_runner)
    │  job 容器: admin/runner-base (预装工具)
    │
    ├─ 1. Checkout          git clone (Gitea NodePort HTTP)
    ├─ 2. Build & Push      docker build -> Nexus 5001
    ├─ 3. Render            envsubst 渲染 secret -> 算 hash -> 渲染 deployment
    ├─ 4. Deploy            kubectl apply (namespace -> secret -> deployment -> service -> ingress)
    ├─ 5. Health Check      kubectl rollout status
    └─ 6. Notify            curl webhook2im -> IM
```

## 组件清单

| 组件 | 部署方式 | 地址 | 职责 |
|------|---------|------|------|
| Gitea | Helm (k8s/gitea/) | NodePort 30021 | 代码仓库 + Actions 调度 |
| act_runner | K8s Deployment (k8s/gitea/runner/) | gitea-http.gitea:3000 | 接收任务并执行 workflow |
| runner-base | Docker 镜像 (Nexus 5001) | 192.168.5.103:5001/admin/runner-base | 预装工具的 job 容器 |
| Nexus | 外部 VM | 192.168.5.103:5001 | Docker 镜像存储 (docker-hosted, HTTP) |
| ci-deployer | K8s ClusterRole (k8s/gitea/runner/) | kube-system | CI/CD 部署专用 SA |
| webhook2im | K8s Deployment | http://webhook2im.webhook2im:3000 | Alertmanager -> 飞书转发 |
| K3s | 4 节点 | 192.168.5.107-111 | 运行工作负载 |

## 核心设计

### 1. 声明式部署 (kubectl apply)

不用 `kubectl set image`，改为 `kubectl apply -f deploy/*.yaml`。git 里的 yaml 就是部署的真实状态，回滚就是 git revert。

apply 顺序固定: namespace -> secret -> deployment -> service -> ingress。

### 2. envsubst 模板替换 + hash 正确顺序

deployment.yaml 中用 `${IMAGE}` 和 `${CONFIG_HASH}` 占位符。关键: **先渲染 secret，再从渲染结果算 hash，最后渲染 deployment**。

```yaml
# deployment.yaml (模板)
image: "${IMAGE}"
annotations:
  checksum/config: "${CONFIG_HASH}"
```

```bash
# workflow 中
export IMAGE="192.168.5.103:5001/admin/webhook2im:${TAG}"
# 1. 先渲染 secret (敏感占位符在此步替换)
envsubst < deploy/secret.yaml > /tmp/secret.yaml
# 2. 从渲染后的 secret 算 hash (配置/密码变更均触发滚动更新)
CONFIG_HASH=$(sha256sum /tmp/secret.yaml | awk '{print $1}')
export CONFIG_HASH
# 3. 渲染其余 yaml
for f in deploy/*.yaml; do
  [ "$(basename $f)" = "secret.yaml" ] && continue
  envsubst < "$f" > "/tmp/$(basename $f)"
done
```

### 3. 敏感信息处理

两层方案，按场景选用:

**方案 A: 环境变量注入 (优先)**
应用支持环境变量时，deployment.yaml 用 secretKeyRef:
```yaml
env:
  - name: DB_DSN
    valueFrom:
      secretKeyRef:
        name: app-secret
        key: db-conn
```
app-secret 由运维手动创建，CI 流水线只 apply 不含密码的 deployment 模板。

**方案 B: envsubst 占位符替换**
应用只支持配置文件时，secret.yaml 中用 `${VAR}` 占位符:
```yaml
# secret.yaml (模板，提交到 git)
stringData:
  config.yaml: |
    db_conn: ${DB_DSN}
```
Gitea Secret 中设置 DB_DSN，workflow Render 步骤通过 env 注入后 envsubst 替换。密码流向: Gitea Secret -> env var -> envsubst 渲染 -> K8s Secret -> Pod 挂载。git 仓库和 Docker 镜像里永远没有明文密码。

### 4. 配置挂载不进镜像

- Dockerfile 不 COPY config.yaml
- K8s 用 Secret 挂载 config.yaml 到容器内
- 配置变更时 `checksum/config` annotation 变化触发 Pod 滚动更新

### 5. Ingress HTTP/HTTPS 双支持

自签证书无安全增益，ingress 加 `ssl-redirect: "false"` 注解，HTTP 不强制跳转 HTTPS:
```yaml
annotations:
  nginx.ingress.kubernetes.io/ssl-redirect: "false"
```

### 6. Gitea Secrets

| Secret | 用途 |
|--------|------|
| `KUBE_TOKEN` | ci-deployer SA token，kubectl 认证 |
| `REGISTRYTOKEN` | Nexus docker registry 密码 |
| `DB_DSN` 等 | 按需，envsubst 注入到 secret.yaml 占位符 |

### 7. runner-base 预装工具镜像

| 工具 | 用途 |
|------|------|
| git | clone 代码 |
| docker CLI | build/push 镜像 (复用 docker.sock) |
| kubectl | 部署 K8s 资源 |
| helm | Helm 部署 (预留) |
| curl/jq/yq | API 调用、JSON/YAML 处理 |
| envsubst | 模板变量替换 |
| dig/nslookup/nc/ss | 网络调试 |
| openssl | 证书调试 |
| vim/less/procps | 通用调试 |

构建: `bash k8s/gitea/runner/runner-image/build-runner-image.sh`

### 8. PVC 持久化 .runner

act_runner 的 `.runner` 注册文件持久化在 NFS PVC 上，pod 重启免重新注册。

### 9. 全内网执行

workflow 中所有网络请求都走内网:
- git clone: `http://192.168.5.107:30021` (Gitea NodePort HTTP)
- docker push: `192.168.5.103:5001` (Nexus)
- kubectl: `https://192.168.5.107:6443` (K3s API)
- 通知: `http://webhook2im.webhook2im:3000` (集群内 Service)

GITEA_URL 使用 NodePort IP 而非 ingress 域名，原因:
- runner job 容器是 host 网络模式，走 IP 最直接不依赖 DNS
- ingress 是自签证书，git clone 需额外跳过证书校验
- 路由器 DNS 在 k3s 节点上不一定可解析

## Alertmanager -> 飞书通道

Alertmanager 的 webhook 与飞书机器人格式不兼容，通过 webhook2im 转发:

```
Alertmanager -> http://webhook2im.webhook2im:3000/alertmanager -> 飞书
```

两套监控栈均已配置:
- kube-prometheus-stack: `k8s/monitoring/kube-prometheus-stack/values-kps.yaml`
- victoria-metrics-k8s-stack: `k8s/monitoring/victoria-metrics-k8s-stack/values-vmstack.yaml`

### 噪音抑制

内置告警 Watchdog 和 InfoInhibitor 路由到 null receiver，不发送通知:
- Watchdog: 心跳告警，仅用于检测告警链路是否存活
- InfoInhibitor: 用于抑制 info 级别告警，本身无意义

### 告警消息格式

webhook2im 使用 Handlebars 模板渲染告警，每条告警包含:
- severity 图标 (🔴critical/🟡warning/🔵info)
- 告警名称、命名空间、实例
- 描述 (含当前值)、摘要
- 开始/结束时间 (可读格式)
- runbook 链接 (如有)

模板位置: `webhook2im/deploy/secret.yaml` 中的 transform 字段。

### 飞书机器人关键词

飞书机器人安全设置需配置关键词 "告警"，否则消息会被拒绝 (返回 Key Words Not Found)。

## 新项目接入 CI/CD

### 1. 创建 deploy/ 目录

```
deploy/
├── namespace.yaml          # Namespace
├── secret.yaml             # 应用配置 (作为 Secret 挂载，敏感值用 ${VAR} 占位符)
├── deployment.yaml         # 镜像用 ${IMAGE}，annotation 用 ${CONFIG_HASH}
├── service.yaml
└── ingress.yaml            # 加 ssl-redirect: "false" 注解
```

### 2. 创建 .gitea/workflows/build.yaml

参考 `k8s/gitea/runner/templates/` 下的模板，修改 env 中的 IMAGE/NAMESPACE。

### 3. 配置 Gitea Secrets

在仓库 Settings -> Actions -> Secrets 中添加:
- `KUBE_TOKEN`: `kubectl -n kube-system get secret ci-deployer-token -o jsonpath='{.data.token}' | base64 -d`
- `REGISTRYTOKEN`: Nexus 密码 (admin123)
- 按需添加敏感变量 (如 `DB_DSN`)，对应 secret.yaml 中的 `${DB_DSN}` 占位符

### 4. Dockerfile

确保 Dockerfile 不 COPY 配置文件，配置通过 K8s 挂载。

### 5. 触发

```bash
git tag v1.0.0
git push origin v1.0.0
# -> 自动触发 build -> push -> deploy -> health check -> notify
```

## 触发方式

- **push tag v***: 完整流程 (build + deploy)
- **workflow_dispatch**: 手动触发 (Gitea Web UI)

## 回滚

```bash
# 回滚到历史版本: 修改 deploy/ yaml 中的镜像 tag 后 apply
# 或 git revert 触发新一次 CI 重新部署旧版本
kubectl -n <namespace> rollout undo deploy/<name>
```

## 前置条件

- Gitea 已部署 (k8s/gitea/)
- runner-base 镜像已构建推送
- ci-deployer SA 已部署 (k8s/gitea/runner/install.sh)
- Nexus 5001 可访问，K3s containerd 已配置 HTTP 直连
