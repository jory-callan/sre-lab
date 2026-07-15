# Gitea Actions Runner

基于 act_runner 的 Gitea Actions 执行引擎，接收 Gitea 工作流任务并在 K8s 中执行。

## 版本

| 组件 | 版本 |
|------|------|
| act_runner | 0.3.1 |
| Helm Chart | 0.1.0 |

## 架构

```
K3s 集群

  ┌──────────────┐     ┌──────────────────────────────┐
  │  Gitea        │     │  act_runner (Deployment)      │
  │  gitea:3000   │◄────│  PVC 持久化 .runner            │
  │  (集群内 svc) │     │  docker.sock 挂载             │
  └──────────────┘     └──────────┬───────────────────┘
                                   │
                        ┌──────────▼───────────────────┐
                        │  Job 容器 (runner-base 镜像)  │
                        │  预装: git/docker/kubectl/    │
                        │        helm/curl/jq/yq/...    │
                        │  docker build/push            │
                        │  kubectl apply                │
                        └──────────────────────────────┘
```

## 前置依赖

- Gitea 已部署
- runner-base 镜像已构建推送（`bash runner-image/build-runner-image.sh`）
- ci-deployer SA 用于 CI/CD 部署（可选，install.sh 会自动部署）

## 部署

```bash
# 1. 获取 registration token
kubectl -n gitea exec deploy/gitea -- /bin/su - git -c \
  "curl -s -X POST -H 'Authorization: token <gitea-admin-token>' \
  'http://localhost:3000/api/v1/admin/actions/runners/registration-token'"

# 2. 写入 chart/values.yaml 的 registrationToken 字段
vim chart/values.yaml

# 3. 部署
bash install.sh install
```

## 验证

```bash
kubectl -n gitea-runner get pods
kubectl -n gitea-runner logs deploy/gitea-runner --tail=10
# 应看到: Runner registered successfully / Starting runner daemon
```

## ci-deployer

集群级 SA，CI/CD workflow 共用此 SA 部署到 K8s。获取 token 存到 Gitea Secret `KUBE_TOKEN`：

```bash
kubectl -n kube-system get secret ci-deployer-token -o jsonpath='{.data.token}' | base64 -d
```

## 常见问题

- **重启后重新注册？** — 不需要，`.runner` 文件持久化在 PVC 上
- **注册失败证书错误？** — `GITEA_INSTANCE_URL` 必须用 `http://gitea-http.gitea:3000`
- **job 容器找不到工具？** — 确认 runner labels 指向 runner-base 镜像
- **Secret 命名限制？** — Gitea 1.26.4 不能含下划线，用全大写（如 `REGISTRYTOKEN`）
