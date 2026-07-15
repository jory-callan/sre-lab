# SRE Playbook

从物理层到 Kubernetes 的完整基础设施 IaC 仓库。

## 全生命周期

```
物理层         OS 层             容器层          K8s 层
network/  →  provisioning/  →  docker-compose/  →  k8s/
```

## 目录说明

| 目录 | 内容 |
|------|------|
| `network/` | 物理网络：交换机配置、上架文档 |
| `provisioning/ansible/` | Ansible roles（linux-init / docker / k3s） |
| `provisioning/scripts/` | 运维脚本（linux / windows / mac） |
| `docker-compose/` | 单机 Docker 服务 |
| `k8s/bootstrap/` | 底座安装（Cilium / MetalLB / ingress-nginx / cert-manager / NFS / monitoring） |
| `k8s/kubeblock/` | KubeBlocks 家族（新派中间件管理，按 addon 引擎分组实例，ns: operators） |
| `k8s/middleware/` | 传统中间件产品（postgres / redis / mysql / gitea / minio / temporal / velero / dolphinscheduler） |
| `k8s/app/` | 自研应用（kite / kdebug） |
| `k8s/lab/` | 选型测试沙箱 / 实验空间 |
| `docs/` | 架构文档、决策记录 |

## 快速开始

```bash
# 1. OS 初始化
bash provisioning/ansible/run.sh linux-init

# 2. 安装 Docker
bash provisioning/ansible/run.sh docker

# 3. 安装 k3s 集群
bash provisioning/ansible/run.sh k3s

# 4. 安装 K8s 底座（在 k3s-server-1 上执行）
bash k8s/bootstrap/install.sh

# 5. 安装应用
bash k8s/apps/install.sh
```

## 设计原则

- 每个组件独立完整，提供 `install.sh` + `uninstall.sh`（支持 install / uninstall 两个参数）
- 远程资源下载到本地，`remote-<name>-<version>` 格式命名，原始文件不修改
- 目录即实例，平铺展开。前缀区分功能，不嵌套子目录
- 不区分 dev/prod 环境文件夹，环境和实例名统一用前缀
- 域名统一使用 `*.czw-sre.internal`
- 目录详细规范见 `k8s/README.md`
