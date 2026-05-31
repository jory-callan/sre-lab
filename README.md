# CZW SRE 项目总览

## 📂 项目结构

```
czw-sre/
├── 01-physical/                    # 第一层：物理层（操作系统、网络）
├── 02-platforms/                   # 第二层：平台层（Docker、k3s 安装部署）
├── 03-infra-docker/                # 第三层：Docker 基础设施应用
├── 03-infra-k8s/                   # 第三层：Kubernetes 基础设施应用
├── 04-apps-docker/                 # 第四层：Docker 业务应用
├── 04-apps-k8s/                    # 第四层：Kubernetes 业务应用
└── docs/                           # 文档
```

---

## 🎯 使用流程

### 从零开始搭建环境

```
1. 物理机初始化
   ↓ 01-physical/linux/init/
   
2. 部署平台
   ↓ 02-platforms/docker/ 或 02-platforms/k3s/
   
3. 部署基础设施应用
   ↓ infra-docker/ 或 infra-k8s/
   
4. 部署业务应用
   ↓ apps-docker/ 或 apps-k8s/
```

---

## 📖 各层说明

| 层级 | 说明 |
|------|------|
| [01-physical/](./01-physical/README.md) | 物理机、操作系统初始化、工具脚本、网络配置 |
| [02-platforms/](./02-platforms/README.md) | Docker、k3s 等平台的安装部署 |
| [03-infra-docker/](./03-infra-docker/README.md) | 用 Docker Compose 部署的中间件和基础设施软件 |
| [03-infra-k8s/](./03-infra-k8s/README.md) | 用 Kubernetes 部署的中间件和基础设施软件 |
| [04-apps-docker/](./04-apps-docker/README.md) | 用 Docker Compose 部署的业务应用 |
| [04-apps-k8s/](./04-apps-k8s/README.md) | 用 Kubernetes 部署的业务应用 |
