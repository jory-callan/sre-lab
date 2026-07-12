# CI/CD 流水线搭建回顾与问题分析

> 日期: 2026-07-12
> 项目: webhook2im CI/CD 流水线（Gitea Actions + K3s）

---

## 一、整体架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        开发者推送 tag                            │
│              git tag v1.0.0 && git push origin v1.0.0           │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  Gitea Actions                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  act_runner (K8s Pod, 运行在 k3s-agent-3)               │    │
│  │                                                         │    │
│  │  1. 拉取代码（从内部 Gitea）                              │    │
│  │  2. docker build → push 到 Gitea 容器注册表               │    │
│  │  3. kubectl set image 更新 K8s Deployment               │    │
│  └─────────────────────────────────────────────────────────┘    │
│                        │                                         │
│                        ▼                                         │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  K3s (containerd) 从 Gitea 注册表拉取新镜像               │    │
│  │  启动新 Pod                                              │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

---

## 二、关键问题与决策分析

### 问题 1：deploy/ 文件夹为什么放在项目里？为什么里面有 RBAC？

**现状：**
```
webhook2im/
├── .gitea/workflows/build.yaml    # CI/CD 流水线
├── deploy/
│   ├── rbac.yaml                   # ci-deployer ServiceAccount + Role
│   └── kustomize/                  # Deployment + Service 模板
```

**问题分析：**
- `rbac.yaml` 是基础设施权限配置，属于集群管理范畴，不应与应用代码放在一起
- `deploy/` 放在应用项目里虽然常见（GitOps 模式），但这里的问题是：
  - RBAC 是 CI/CD 基础设施的一部分，不是应用本身的部署配置
  - 应用仓库应该只包含应用自身的部署清单（Deployment、Service、ConfigMap）

**正确做法：**
- `rbac.yaml` → 移到 `sre-lab/k8s/webhook2im/` 基础设施仓库
- `deploy/kustomize/` → 可以保留在应用项目（方便 CI 直接使用），或也移到基础设施仓库
- 工作流中部署时不再内联 YAML，而是引用 kustomize 模板

### 问题 2：为什么需要 actions/checkout@v4？为什么要改？

**问题根因：**
- 原 workflow 使用 `actions/checkout@v4`，这是 GitHub 官方的 Action
- act_runner 执行 job 时，需要从 GitHub 下载这个 action 的代码
- **国内服务器无法访问 GitHub**，导致任务卡死

**修复方案：**
- 替换为 `git clone` 直接从内部 Gitea 拉取代码
- 使用 Gitea 内部 Service 地址 `http://gitea-http.gitea:3000`（集群内 DNS）

**教训：** 整个环境应该零外部依赖。所有外部资源（镜像、代码）都应通过内部代理/镜像访问。

### 问题 3：Docker vs containerd，到底用哪个？

这是最混乱的地方，我解释清楚：

| 组件 | 容器运行时 | 用途 |
|------|-----------|------|
| **K3s 集群** | **containerd** | 运行所有 K8s Pod（包括 act_runner、webhook2im 等） |
| **宿主机** | **Docker** | act_runner 通过挂载 `/var/run/docker.sock` 调用宿主机 Docker |
| **act_runner job 容器** | Docker（由宿主机 Docker 创建） | 执行 workflow 步骤（docker build、kubectl 等） |

**工作流程：**
```
act_runner (Pod, containerd)
  └─ 挂载 /var/run/docker.sock
      └─ 调用宿主机 Docker 创建 job 容器
          └─ job 容器内执行 docker build → push 到 Gitea 注册表
              └─ K8s (containerd) 从 Gitea 注册表拉取镜像
```

**为什么需要配置 containerd？**
- Docker build 推送到 `gitea.czw-sre.internal` 注册表
- K8s 调度新 Pod 时，**kubelet 使用 containerd** 拉取镜像
- containerd 不认识 `gitea.czw-sre.internal`，需要配置 registries.yaml 告诉它去哪里拉、是否跳过 TLS

**为什么需要配置 Docker？**
- job 容器内执行 `docker push gitea.czw-sre.internal/...` 时
- Docker daemon 默认拒绝非 HTTPS 的 registry
- 需要在 Docker daemon.json 中添加 `insecure-registries`

**有没有更简单的方案？**

有，以下几种：

#### 方案 A：全 Docker 链路（当前方案）
- 宿主机 Docker + containerd 都需要配置
- 优点：docker build 最成熟
- 缺点：两套运行时都要维护

#### 方案 B：只用 containerd（推荐）
- 用 **kaniko** 或 **buildkit** 在容器内构建镜像，无需 Docker daemon
- 构建产物直接推送到 Gitea 注册表
- K8s 用 containerd 拉取
- **只需要配置 containerd，不需要 Docker**
- 缺点：需要学习 kaniko/buildkit

#### 方案 C：Docker-in-Docker（DinD）
- 在 job 容器内运行一个独立的 Docker daemon
- 不依赖宿主机 Docker
- 但性能差、镜像层缓存丢失

#### 方案 D：使用 Nexus 作为中转
- Docker build → push 到 Nexus（已配好 HTTP）
- K8s 从 Nexus 拉取（containerd 已配好 Nexus mirror）
- 但多了一跳，不直接

**我的判断：方案 B（kaniko）是最干净的，但当前方案 A 已经能工作。**

### 问题 4：为什么改 containerd registries.yaml 丢了注释和原有配置？

这是一个操作失误。用 Python YAML 库读写时，YAML 的注释会被丢弃。应该用 `sed` 或手动编辑方式追加内容，而不是用 `yaml.dump` 重写整个文件。

---

## 三、实际完成的工作

### 3.1 代码修改

| 文件 | 修改内容 |
|------|---------|
| `webhook2im/.gitea/workflows/build.yaml` | `actions/checkout@v4` → `git clone` 从内部 Gitea |
| `webhook2im/.gitea/workflows/build.yaml` | registry 地址统一为 `gitea.czw-sre.internal`（HTTP） |
| `webhook2im/.gitea/workflows/build.yaml` | 添加 Docker insecure-registries 配置步骤 |
| `webhook2im/deploy/rbac.yaml` | 扩展 ci-deployer 权限（+create services/namespaces） |

### 3.2 基础设施变更

| 操作 | 范围 |
|------|------|
| Docker daemon.json 添加 `insecure-registries` | 所有 4 节点 |
| containerd registries.yaml 添加 Gitea mirror | 所有 4 节点（但操作有瑕疵，丢了注释） |
| K3s 重启（使 containerd 配置生效） | 所有 4 节点 |
| RBAC apply | webhook2im namespace |

### 3.3 流水线触发结果

- ✅ Tag `v1.0.0` 推送成功
- ✅ Gitea Actions 创建 run #1
- ✅ Runner 接任务（日志：`task 1 repo is admin/webhook2im`）
- ❌ 卡在 `actions/checkout@v4`（GitHub 无法访问）
- ✅ 旧 run 已取消
- ⏳ 新 workflow 已推送（main），等待推送新 tag 测试

---

## 四、当前状态

```
webhook2im 仓库 main 分支: 已包含修复后的 workflow
基础设施配置: Docker + containerd 均已配置 Gitea 注册表
Runner: 运行中，已注册
旧任务: 已取消
```

**下一步：** 推送新 tag 触发流水线测试。

---

## 五、改进建议

1. **RBAC 移入基础设施仓库** — `sre-lab/k8s/webhook2im/rbac.yaml`
2. **考虑 kaniko 替代 Docker build** — 消除对宿主机 Docker 的依赖
3. **containerd 配置改用 sed 追加** — 避免 YAML 库吃掉注释
4. **registries.yaml 纳入 Ansible 管理** — 在 `sre-lab/provisioning/ansible/roles/k3s/files/registries.yaml` 中统一维护
5. **workflow 内联 YAML 改为引用 kustomize** — 更清晰
