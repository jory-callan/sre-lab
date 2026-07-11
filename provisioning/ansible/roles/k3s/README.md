# K3s Ansible Role

通过 Ansible 自动化安装 k3s 集群，支持 Server + Agent 混合部署。

## 设计原则

- **配置文件作为文件** — `files/config.yaml` 和 `files/config-agent.yaml` 是纯 YAML 文件，不是 Jinja2 模板。动态值（token、IP、cluster-init）通过 `replace`/`lineinfile` 注入
- **最少变量** — hosts.ini 只定义 `k3s_version` 和 `k3s_token` 两个变量。`k3s_server_url` 从 inventory 自动推导
- **已安装检测** — 通过 `which k3s` 判断，已安装则跳过安装步骤（配置始终重新部署）

## 变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `k3s_version` | k3s 版本 | v1.31.5-k3s1 |
| `k3s_token` | 集群认证 token | 必填 |

## 主机组

```ini
[k3s_server]
k3s-server-1 ansible_host=192.168.5.110

[k3s_agent]
k3s-agent-1 ansible_host=192.168.5.111
k3s-agent-2 ansible_host=192.168.5.112

[k3s_cluster:children]
k3s_server
k3s_agent
```

## 执行顺序

1. `k3s_server` 组串行执行（`serial: 1`）— 第一个节点 `cluster-init: true`，其余加入
2. `k3s_agent` 组并行执行 — 全部连接到第一个 server

## 配置文件

| 文件 | 目标路径 | 说明 |
|------|----------|------|
| `files/config.yaml` | `/etc/rancher/k3s/config.yaml` | Server 配置（含 apiserver/etcd/kubelet 参数） |
| `files/config-agent.yaml` | `/etc/rancher/k3s/config.yaml` | Agent 配置（精简版） |
| `files/registries.yaml` | `/etc/rancher/k3s/registries.yaml` | 镜像源配置（私有 registry 代理） |

## 动态注入

| 占位符 | 注入值 | 适用节点 |
|--------|--------|----------|
| `CHANGE_ME` (token) | `k3s_token` | 所有节点 |
| `# ANSIBLE_CLUSTER_INIT: true` | `cluster-init: true/false` | Server |
| `# ANSIBLE_SERVER_URL` | `server: https://IP:6443` | 加入的 Server |
| `# ANSIBLE_TLS_SAN_IPS` | 所有 server 节点 IP | Server |
| `server: https://CHANGE_ME:6443` | 第一个 server IP | Agent |

## 使用

```bash
cd ansible

# 预览
bash check.sh k3s

# 安装
bash run.sh k3s

# 指定 tags
ansible-playbook playbooks/k3s.yml -i inventories/production/hosts.ini --tags k3s
```
