# keepalived-haproxy

为 k3s API Server 提供高可用 VIP 和负载均衡。

## 原理

- **haproxy**：在每个 server 节点上监听 `0.0.0.0:6443`，以轮询方式转发到所有 server 节点的 `6443` 端口
- **keepalived**：通过 VRRP 提供 VIP 漂移，首节点为 MASTER，其余为 BACKUP

## 变量

| 变量 | 说明 | 示例 |
|------|------|------|
| `vip_address` | Keepalived 虚拟 IP | `192.168.5.254` |
| `groups['k3s_server']` | 所有 server 节点（自动获取） | — |

## 对 k3s 的影响

- 所有 agent 节点通过 `https://VIP:6443` 连接 k3s API Server
- 加入集群的 server 节点也通过 `https://VIP:6443` 连接
- 节点故障时 VIP 自动漂移到健康节点，API Server 不中断

## 注意事项

- 前置条件：k3s server 已安装并运行在 `6443` 端口
- 单节点同样生效，节点恢复后 VIP 自动回切
