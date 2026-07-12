# CI/CD 流水线 — 架构说明

> 2026-07-12 | 项目: webhook2im | 引擎: Gitea Actions + Nexus 镜像仓库

## 架构

```
开发者 push tag
  → Gitea Actions (act_runner)
    → git clone 从内部 Gitea
    → docker build
    → docker push 到 Nexus (192.168.5.103:5001)
    → kubectl set image 更新 K8s Deployment
    → K8s (containerd) 从 Nexus 拉取新镜像
```

## 组件

| 组件 | 位置 | 职责 |
|------|------|------|
| Gitea | k8s/gitea/ | 代码仓库 + Actions 调度 |
| act_runner | k8s/gitea/runner/ | K8s Deployment，接收 Gitea Actions 任务并执行 |
| Nexus | 192.168.5.103:5001 | Docker 镜像仓库（docker-hosted） |
| K3s | 4 节点集群 | 运行所有工作负载 |

## 关键配置

- **act_runner** 使用 `host` 网络模式 + 挂载宿主机 `docker.sock`，job 容器内可直接 docker build/push
- **镜像仓库地址**: `192.168.5.103:5001`（Nexus docker-hosted，HTTP）
- **K8s 内部 Gitea 地址**: `http://gitea-http.gitea:3000`
- **K8s API**: job 容器通过 ServiceAccount token 内联 kubeconfig 访问

## 项目 workflow

`webhook2im/.gitea/workflows/build.yaml` — tag 触发，步骤：

1. git clone 代码
2. 安装 docker CLI + kubectl
3. docker login Nexus → docker build → docker push
4. kubectl set image 更新 webhook2im Deployment

## 前置条件

- Gitea Secrets 已设置 `REGISTRYTOKEN`（Nexus 密码）、`KUBE_TOKEN`（ci-deployer SA token）
- `webhook2im` 命名空间已创建 ci-deployer ServiceAccount（`deploy/rbac.yaml`）
- 所有 K3s 节点的 Docker daemon 已配置 Nexus `insecure-registries`
- 所有 K3s 节点的 containerd 已配置 Nexus mirror

## 与旧方案的区别

| 对比项 | 旧方案 | 当前方案 |
|--------|--------|----------|
| 镜像仓库 | Gitea 容器注册表 | Nexus docker-hosted |
| registry 地址 | gitea.czw-sre.internal | 192.168.5.103:5001 |
| 依赖组件 | Gitea packages + 额外 containerd 配置 | Nexus（已有） |
| 复杂度 | 高（两套 registry 配置） | 低（统一 Nexus） |
