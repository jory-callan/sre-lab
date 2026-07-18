# K3s Ansible Role

通过 Ansible 自动化安装 k3s 集群，支持 Server + Agent 混合部署。

## 设计原则

- **配置文件是纯 YAML，不是模板** — 动态值通过 `replace`/`lineinfile`/`blockinfile` 注入占位符
- **占位符统一** — 所有待替换值用 `__CHANGEME_*__` 格式，一眼可识别
- **已安装检测** — 通过 `which k3s` 判断，已安装则跳过安装步骤（配置始终重新部署）

## 变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `k3s_version` | k3s 版本 | 必填 |
| `k3s_token` | 集群认证 token | 必填 |
| `k3s_data_dir` | 数据目录 | 必填 |
| `vip_address` | Keepalived VIP | 必填 |
| `k3s_tls_san` | 额外 TLS SAN 条目（JSON 数组） | 可选 |

## 主机组

```ini
[k3s_server]
k3s-server-1 ansible_host=192.168.5.123

[k3s_agent]
k3s-agent-1 ansible_host=192.168.5.124
k3s-agent-2 ansible_host=192.168.5.125

[k3s_cluster:children]
k3s_server
k3s_agent
```

## 执行顺序

1. `k3s_server` 组串行执行（`serial: 1`）— 首节点 `cluster-init: true`，其余通过 VIP 加入
2. `k3s_agent` 组并行执行 — 全部通过 VIP 连接 API Server
3. `k3s_server` 组安装 keepalived + haproxy — 提供 VIP 高可用

## 配置文件

| 文件 | 目标路径 | 说明 |
|------|----------|------|
| `files/config.yaml` | `/etc/rancher/k3s/config.yaml` | Server 配置（含 apiserver/etcd/kubelet 参数） |
| `files/config-agent.yaml` | `/etc/rancher/k3s/config.yaml` | Agent 配置（精简版） |
| `files/registries.yaml` | `/etc/rancher/k3s/registries.yaml` | 镜像源配置（私有 registry 代理） |

## 动态注入

| 占位符 | 注入值 | 适用节点 |
|--------|--------|----------|
| `__CHANGEME_TOKEN__` | `k3s_token` | 所有节点 |
| `__CHANGEME_DATA_DIR__` | `k3s_data_dir` | 所有节点 |
| `__CHANGEME_CLUSTER_INIT__` | `cluster-init: true/false` | Server |
| `__CHANGEME_SERVER_URL__` | `server: https://VIP:6443` | 加入的 Server |
| `__CHANGEME_VIP__` | `vip_address` | Agent |
| `__CHANGEME_TLS_SAN_IPS__` | 所有 server 节点 IP | Server |
| `__CHANGEME_TLS_SAN_HOSTNAMES__` | 所有 server 节点 hostname | Server |
| `__CHANGEME_TLS_SAN_EXTRA__` | `k3s_tls_san` 数组条目 | Server |

## 自动维护

### /etc/hosts

通过 `blockinfile` 维护以下映射（标记块 `# === K3S MANAGED BLOCK ===`）：

- 所有 server 节点 hostname → 对应 IP
- `k3s_tls_san` 中的域名条目 → VIP 地址

用户自定义的 `/etc/hosts` 条目不受影响。

## 使用

```bash
cd ansible

# 安装
bash run.sh k3s

# 卸载（手动运行，不自动执行）
bash run.sh k3s --tags uninstall -l <host>
```
