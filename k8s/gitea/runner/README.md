# Gitea Actions Runner - 部署指南

## 架构

```
┌──────────────────────────────────────────────────────────────┐
│  K3s 集群                                                     │
│                                                               │
│  ┌──────────────┐     ┌──────────────────────────────┐       │
│  │  Gitea        │     │  act_runner (Deployment)      │       │
│  │  gitea:3000   │◄────│  PVC 持久化 .runner            │       │
│  │  (集群内 svc) │     │  docker.sock 挂载             │       │
│  └──────────────┘     └──────────┬───────────────────┘       │
│                                   │                            │
│                        ┌──────────▼───────────────────┐       │
│                        │  Job 容器 (runner-base 镜像)  │       │
│                        │  预装: git/docker/kubectl/    │       │
│                        │        helm/curl/jq/yq/...    │       │
│                        │  docker build/push            │       │
│                        │  kubectl apply                │       │
│                        └──────────────────────────────┘       │
└──────────────────────────────────────────────────────────────┘
```

- **act_runner** 作为 K8s Deployment 运行，PVC 持久化 .runner 文件，pod 重启免重新注册
- **runner-base** 预装工具镜像，job 容器直接使用，无需每次安装工具
- 挂载宿主机 `docker.sock`，workflow job 容器内可直接执行 `docker build/push`
- 使用 `host` 网络模式，job 容器可直接访问集群内 Service

## 文件清单

| 文件 | 说明 |
|------|------|
| `runner.yaml` | act_runner Deployment (含 Namespace/Secret/ConfigMap/PVC/Deployment) |
| `runner-config.yaml` | runner 配置文件 (同 ConfigMap 内容) |
| `ci-deployer.yaml` | 集群级 ci-deployer ServiceAccount + ClusterRole |
| `install.sh` | 幂等部署脚本 |
| `uninstall.sh` | 卸载脚本 |
| `runner-image/Dockerfile` | runner-base 预装工具镜像 |
| `runner-image/build-runner-image.sh` | 在 K3s 节点构建并推送 runner-base 镜像 |
| `templates/` | 各语言 CI/CD workflow 模板 |

## 部署步骤

### 1. 构建 runner-base 镜像（一次性）

```bash
bash runner-image/build-runner-image.sh
```

在 K3s 节点上构建并推送到 Nexus: `192.168.5.103:5001/admin/runner-base:latest`

### 2. 获取 Runner Registration Token

```bash
# 获取 Gitea admin token
curl -sk -X POST "http://192.168.5.107:30021/api/v1/users/admin/tokens" \
  -u "admin:Admin@czw123" \
  -H "Content-Type: application/json" \
  -d '{"name":"runner-setup","scopes":["write:admin"]}'

# 用 admin token 获取 registration token (实例级，所有 runner 共用)
curl -sk -X POST \
  -H "Authorization: token <gitea-admin-token>" \
  "http://192.168.5.107:30021/api/v1/admin/actions/runners/registration-token"
```

### 3. 配置并部署 Runner

```bash
# 编辑 runner.yaml，将 Secret 中的 token 替换为实际 registration token
vim runner/runner.yaml

# 部署 (幂等)
bash runner/install.sh
```

### 4. 验证

```bash
kubectl -n gitea-runner get pods
kubectl -n gitea-runner logs deploy/gitea-runner --tail=10
# 应看到: Runner registered successfully / Starting runner daemon
```

## ci-deployer ServiceAccount

集群级 SA，所有项目的 CI/CD workflow 共用此 SA 部署到 K8s。

获取 token（存到 Gitea Secret `KUBE_TOKEN`）:

```bash
kubectl -n kube-system get secret ci-deployer-token -o jsonpath='{.data.token}' | base64 -d
```

权限: namespaces/pods/services/configmaps/secrets/deployments/ingresses 的 CRUD。

## 常见问题

### Q: Runner 重启后需要重新注册吗？

不需要。`.runner` 文件持久化在 PVC (NFS) 上，pod 重启直接复用。仅当 PVC 丢失或在 Gitea UI 里 regenerate token 时才需要重新注册。

### Q: Runner 注册失败，报证书错误

`GITEA_INSTANCE_URL` 必须用集群内 Service 地址 `http://gitea-http.gitea:3000`，不能用 HTTPS 域名（ingress-nginx 默认证书不匹配）。

### Q: job 容器找不到 docker/kubectl 等工具

确认 runner labels 指向 runner-base 镜像:
```
ubuntu-latest:docker://192.168.5.103:5001/admin/runner-base:latest
```

### Q: Helm upgrade 后 Gitea Pod 起不来 (SQLite 锁)

```bash
kubectl delete pod -n gitea <旧pod名> --force --grace-period=0
```

### Q: Secret 命名限制

Gitea 1.26.4 的 secret 名不能包含下划线，用全大写无下划线命名（如 `REGISTRYTOKEN`、`KUBE_TOKEN` 实测可用）。
