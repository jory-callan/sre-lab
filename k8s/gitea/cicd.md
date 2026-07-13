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
    ├─ 1. Checkout          git clone (Gitea NodePort)
    ├─ 2. Build & Push      docker build -> Nexus 5001
    ├─ 3. Render            envsubst 替换 ${IMAGE} ${CONFIG_HASH}
    ├─ 4. Deploy            kubectl apply -f deploy/*.yaml
    ├─ 5. Health Check      kubectl rollout status
    └─ 6. Notify            curl webhook2im -> IM

deploy/ 目录 (扁平 yaml):
├── namespace.yaml
├── secret.yaml             # config.yaml 作为 Secret 挂载
├── deployment.yaml         # ${IMAGE} + ${CONFIG_HASH} 占位符
├── service.yaml
└── ingress.yaml
```

## 组件清单

| 组件 | 部署方式 | 地址 | 职责 |
|------|---------|------|------|
| Gitea | Helm (k8s/gitea/) | https://gitea.czw-sre.internal | 代码仓库 + Actions 调度 |
| act_runner | K8s Deployment (k8s/gitea/runner/) | gitea-http.gitea:3000 | 接收任务并执行 workflow |
| runner-base | Docker 镜像 (Nexus 5001) | 192.168.5.103:5001/admin/runner-base | 预装工具的 job 容器 |
| Nexus | 外部 VM | 192.168.5.103:5001 | Docker 镜像存储 (docker-hosted, HTTP) |
| ci-deployer | K8s ClusterRole (k8s/gitea/runner/) | kube-system | CI/CD 部署专用 SA |
| K3s | 4 节点 | 192.168.5.107-111 | 运行工作负载 |

## 核心设计

### 1. 声明式部署 (kubectl apply)

不用 `kubectl set image`，改为 `kubectl apply -f deploy/*.yaml`。git 里的 yaml 就是部署的真实状态，回滚就是 git revert。

### 2. envsubst 模板替换

deployment.yaml 中用 `${IMAGE}` 和 `${CONFIG_HASH}` 占位符，CI 时 envsubst 替换为实际值:

```yaml
# deployment.yaml (模板)
image: "${IMAGE}"
annotations:
  checksum/config: "${CONFIG_HASH}"
```

```bash
# workflow 中
export IMAGE="192.168.5.103:5001/admin/webhook2im:${TAG}"
CONFIG_HASH=$(sha256sum deploy/secret.yaml | awk '{print $1}')
export CONFIG_HASH
envsubst < deploy/deployment.yaml > /tmp/deployment.yaml
kubectl apply -f /tmp/deployment.yaml
```

### 3. 配置挂载不进镜像

- Dockerfile 不 COPY config.yaml
- K8s 用 Secret 挂载 config.yaml 到容器内
- 配置变更时 `checksum/config` annotation 变化触发 Pod 滚动更新

### 4. 敏感信息通过 Gitea Secrets

| Secret | 用途 |
|--------|------|
| `KUBE_TOKEN` | ci-deployer SA token，kubectl 认证 |
| `REGISTRYTOKEN` | Nexus docker registry 密码 |

### 5. runner-base 预装工具镜像

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

### 6. PVC 持久化 .runner

act_runner 的 `.runner` 注册文件持久化在 NFS PVC 上，pod 重启免重新注册。

### 7. 全内网执行

workflow 中所有网络请求都走内网:
- git clone: `https:/gitea.czw-sre.internal` (Gitea NodePort)
- docker push: `192.168.5.103:5001` (Nexus)
- kubectl: `https://192.168.5.107:6443` (K3s API)
- 通知: `http://webhook2im.webhook2im:3000` (集群内 Service)

## 新项目接入 CI/CD

### 1. 在项目仓库创建 deploy/ 目录

```
deploy/
├── namespace.yaml          # Namespace
├── secret.yaml             # 应用配置 (作为 Secret 挂载)
├── deployment.yaml         # 镜像用 ${IMAGE}，annotation 用 ${CONFIG_HASH}
├── service.yaml
└── ingress.yaml            # 可选
```

### 2. 创建 .gitea/workflows/build.yaml

参考 `k8s/gitea/runner/templates/` 下的模板，修改 env 中的 IMAGE/NAMESPACE。

### 3. 配置 Gitea Secrets

在仓库 Settings -> Actions -> Secrets 中添加:
- `KUBE_TOKEN`: `kubectl -n kube-system get secret ci-deployer-token -o jsonpath='{.data.token}' | base64 -d`
- `REGISTRYTOKEN`: Nexus 密码 (admin123)

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
