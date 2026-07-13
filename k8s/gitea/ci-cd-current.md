# CI/CD 流水线 — 当前方案

> 2026-07-13 | 引擎: Gitea Actions + Nexus 镜像仓库 | 项目: webhook2im

## 架构总览

```
开发者 push tag
    │
    ▼
┌─ Gitea Actions ─────────────────────────────────────┐
│  act_runner (K8s Deployment)                        │
│  host 网络 + docker.sock                            │
│  job 容器: ubuntu:24.04                             │
└─────────────────────┬───────────────────────────────┘
                      │
                      ▼
┌─ Job 容器内步骤 ────────────────────────────────────┐
│  1. Install Tools   git / docker / kubectl          │
│  2. Checkout        git clone (Gitea NodePort)      │
│  3. Login           docker login Nexus 5001         │
│  4. Build & Push    docker build → docker push      │
│  5. Deploy          kubectl set image               │
└─────────────────────┬───────────────────────────────┘
                      │
                      ▼
┌─ K3s 集群 ──────────────────────────────────────────┐
│  containerd → hosts.toml → HTTP 拉取 Nexus 5001     │
│  → Pod Rolling Update                               │
└─────────────────────────────────────────────────────┘
```

## 组件清单

| 组件 | 部署方式 | 地址 | 职责 |
|------|---------|------|------|
| Gitea | Helm (k8s/gitea/) | https://gitea.czw-sre.internal | 代码仓库 + Actions 调度 |
| act_runner | K8s Deployment (k8s/gitea/runner/) | gitea-http.gitea:3000 | 接收任务并执行 workflow |
| Nexus | 外部 VM | 192.168.5.103:5001 | Docker 镜像存储 (docker-hosted, HTTP) |
| K3s | 4 节点 (1 server + 3 agent) | 192.168.5.107-111 | 运行工作负载 |

## Workflow 定义

文件: `项目/.gitea/workflows/build.yaml`

```yaml
name: Build and Deploy
on:
  push:
    tags:
      - '*'          # 任何 tag 推送触发
jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - Install Tools     # apt install git docker.io curl + kubectl
      - Checkout          # git clone --depth 1 --branch <tag>
      - Login to Nexus    # docker login 192.168.5.103:5001
      - Build & Push      # docker build → push <tag> + latest
      - Deploy to K8s     # kubectl set image deploy/<name>
```

## 关键配置

### act_runner (runner-config.yaml)

```yaml
container:
  network_mode: host                    # job 容器复用宿主机网络
  options: -v /var/run/docker.sock:/var/run/docker.sock   # 复用宿主机 docker
```

### K3s containerd (registries.yaml)

```yaml
configs:
  192.168.5.103:5001:
    tls:
      insecure_skip_verify: true
mirrors:
  # 5001/5000 不在 mirrors 中 — 避免 k3s 生成 HTTPS server
  docker.io:
    endpoint:
    - http://192.168.5.103:5002
```

containerd 自动生成 hosts.toml:
```
server = "http://192.168.5.103:5001/v2"   # ← HTTP 直连
capabilities = ["pull", "resolve", "push"]
skip_verify = true
```

### K8s 认证 (内联 kubeconfig)

```yaml
# workflow 内动态生成
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: https://192.168.5.107:6443
    insecure-skip-tls-verify: true
  name: k3s
users:
- name: ci-deployer
  user:
    token: ${KUBE_TOKEN}   # ← Gitea Secret
```

## 前置条件

- Gitea Secrets: `REGISTRYTOKEN` (Nexus 密码)、`KUBE_TOKEN` (ci-deployer SA token)
- 各项目命名空间已创建 `ci-deployer` ServiceAccount (Role: deployments get/patch)
- K3s 节点 registries.yaml 已配置 Nexus HTTP 直连
- act_runner 已注册到 Gitea

## 触发方式

```bash
git tag v1.2.3
git push origin v1.2.3
# → 自动触发 build → push → deploy
```

## 已验证

- Run #11: conclusion=success
- 镜像已推送: `192.168.5.103:5001/admin/webhook2im:v1.1.0`
- Pod 已 Running (4 节点 containerd 均可拉取)

## 局限

| 问题 | 说明 |
|------|------|
| 单 runner | 无 HA，runner 故障时流水线阻塞 |
| 无缓存 | 每次全量构建，无 layer 缓存加速 |
| 无安全扫描 | 镜像不扫描漏洞 |
| 无环境隔离 | 直接部署到生产命名空间 |
| 无回滚 | kubectl set image 不保留版本历史 |
| 无审批 | tag 即部署，无人工审核 |
| 无测试步骤 | workflow 无单元/集成测试 |
| 无通知 | 流水线失败无告警 |
| 单架构 | 仅 amd64 构建 |
| 无 GitOps | 声明式 vs 命令式部署 |
