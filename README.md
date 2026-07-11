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
| `k8s/bootstrap/` | 底座安装（Cilium / MetalLB / ingress-nginx / cert-manager / NFS） |
| `k8s/operators/` | Operator 控制面（cnpg / redis / minio，ns: operators） |
| `k8s/monitoring/` | 监控告警（VictoriaMetrics / VictoriaLogs / FluentBit / Grafana，ns: monitoring） |
| `k8s/postgresql/` | PostgreSQL 17（CNPG operator，ns: postgresql） |
| `k8s/redis/` | Redis 7.4（manifests / helm / operator，ns: redis） |
| `k8s/minio/` | MinIO 对象存储（Operator，ns: minio） |
| `k8s/mysql/` | MySQL（manifests / operator，ns: mysql） |
| `k8s/gitea/` | 自托管 Git 服务（ns: gitea） |
| `k8s/kite/` | K8s Web UI（ns: kite） |
| `k8s/kdebug/` | 调试工具（ns: kdebug） |
| `k8s/temporal/` | 工作流引擎（ns: temporal） |
| `k8s/velero/` | 集群备份（ns: velero） |
| `k8s/lab/` | 选型测试沙箱 |
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

- 每个组件独立完整，提供 `install.sh` + `uninstall.sh`
- 远程资源下载到本地，`remote-<name>-<version>` 格式命名，原始文件不修改
- 部署方式（manifests / helm / kustomize）通过子目录区分
- 不区分 dev/prod 环境文件夹，确需区分时用文件名后缀
- 域名统一使用 `*.czw-sre.internal`
