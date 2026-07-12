# Gitea Actions Runner — 部署指南

## 架构

```
┌──────────────────────────────────────────────────────────┐
│  K3s 集群                                                 │
│                                                           │
│  ┌──────────────┐     ┌──────────────────────────────┐   │
│  │  Gitea        │     │  act_runner (Deployment)      │   │
│  │  gitea:3000   │◄────│  k8s-runner-1                 │   │
│  │  (集群内 Service) │     │                              │   │
│  └──────────────┘     │  labels: ubuntu-latest          │   │
│                        │  docker.sock: /var/run/docker   │   │
│                        └──────────┬───────────────────┘   │
│                                   │                        │
│                        ┌──────────▼───────────────────┐   │
│                        │  Job 容器 (workflow 执行)      │   │
│                        │  docker build/push            │   │
│                        │  kubectl set image            │   │
│                        └──────────────────────────────┘   │
└──────────────────────────────────────────────────────────┘
```

- **act_runner** 作为 K8s Deployment 运行，通过集群内 Service 连接 Gitea
- 挂载宿主机 `docker.sock`，workflow job 容器内可直接执行 `docker build/push`
- 使用 `host` 网络模式，job 容器可直接访问集群内 Service（如 `kubernetes.default.svc`）

## 前置条件

- Gitea 已部署（见 `../README.md`）
- Gitea 容器注册表已启用（`values.yaml` 中 `packages.ENABLED: true`）
- 宿主机有 Docker 运行时（K3s 节点上已有 docker）

## 部署步骤

### 1. 获取 Runner Registration Token

```bash
# 方式一：API（替换 TOKEN 和 owner/repo）
curl -sk -X POST \
  -H "Authorization: token <你的AccessToken>" \
  "https://gitea.czw-sre.internal/api/v1/repos/<owner>/<repo>/actions/runners/registration-token"

# 方式二：Gitea Web UI
# 仓库 → Settings → Actions → Runners → Create Registration Token
```

### 2. 配置并部署 Runner

```bash
# 编辑 runner.yaml，将 token 替换为实际值
vim runner/runner.yaml

# 部署
kubectl apply -f runner/runner.yaml
```

### 3. 验证

```bash
kubectl get pods -n gitea-runner
# NAME                            READY   STATUS    RESTARTS   AGE
# gitea-runner-58565666f9-jwphf   1/1     Running   0          1m

kubectl logs -n gitea-runner deploy/gitea-runner --tail=10
# 应看到:
#   Runner registered successfully.
#   Starting runner daemon
#   runner: k8s-runner-1 ... declare successfully
```

### 4. 在 Gitea 仓库设置 Secrets

workflow 中需要以下 Secrets（在仓库 Settings → Actions → Secrets 中添加）：

| Secret | 用途 | 获取方式 |
|--------|------|---------|
| `KUBE_TOKEN` | K8s API 认证 | `kubectl get secret -n <ns> ci-deployer-token -o jsonpath='{.data.token}' \| base64 -d` |
| `REGISTRYTOKEN` | Docker login 到 Gitea 容器注册表 | Gitea Access Token（用户 Settings → Applications → Generate Token） |

#### 创建 ci-deployer ServiceAccount

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: <你的项目命名空间>
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ci-deployer
  namespace: <你的项目命名空间>
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ci-deployer
  namespace: <你的项目命名空间>
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ci-deployer
  namespace: <你的项目命名空间>
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ci-deployer
subjects:
  - kind: ServiceAccount
    name: ci-deployer
    namespace: <你的项目命名空间>
---
apiVersion: v1
kind: Secret
metadata:
  name: ci-deployer-token
  namespace: <你的项目命名空间>
  annotations:
    kubernetes.io/service-account.name: ci-deployer
type: kubernetes.io/service-account-token
EOF

# 获取 token
kubectl get secret -n <你的项目命名空间> ci-deployer-token -o jsonpath='{.data.token}' | base64 -d
```

## 工作流模板

`templates/` 目录下提供了以下模板：

| 模板 | 适用场景 |
|------|---------|
| `nodejs.yaml` | Node.js 项目（Dockerfile 构建） |
| `golang.yaml` | Go 项目（多阶段构建） |
| `java21.yaml` | Java 21 + Maven 项目 |

使用方式：复制到项目 `.gitea/workflows/` 目录，按需修改。

## 常见问题

### Q: Runner 注册失败，报证书错误

```
Cannot ping the Gitea instance server
error: tls: failed to verify certificate: x509: certificate is valid for ingress.local, not gitea.czw-sre.internal
```

**原因**：用 HTTPS 域名连接 Gitea，但 ingress-nginx 默认证书不匹配。

**解决**：`GITEA_INSTANCE_URL` 改为集群内 Service 地址：
```
http://gitea-http.gitea:3000
```

### Q: Workflow 中 docker build 失败

```
docker: command not found
```

**原因**：job 容器内没有 docker CLI。

**解决**：在 workflow 中安装 docker CLI，并确保 runner 配置了 `options: -v /var/run/docker.sock:/var/run/docker.sock`。

### Q: Gitea 容器注册表返回 401

**原因**：Gitea 的 `packages.ENABLED` 未开启。

**解决**：在 `values.yaml` 中添加：
```yaml
gitea:
  config:
    packages:
      ENABLED: true
```
然后 `helm upgrade`。注意 SQLite 锁问题（见下方）。

### Q: Helm upgrade 后新 Pod 起不来

```
Failed to create queue "notification-service":
unable to lock level db at /data/queues/common: resource temporarily unavailable
```

**原因**：旧 Pod 持有 SQLite 锁，新 Pod 无法获取。

**解决**：force delete 旧 Pod：
```bash
kubectl delete pod -n gitea <旧pod名> --force --grace-period=0
```

### Q: Gitea Secrets API 拒绝 secret 名

```
invalid variable or secret name
```

**原因**：Gitea 对 secret 名字有限制（不能含下划线等字符）。

**解决**：使用全大写字母或连字符，如 `REGISTRYTOKEN`、`KUBE_TOKEN`（KUBE_TOKEN 实测可用）。
