# keepalived-haproxy

为 k3s API Server 提供高可用 VIP 和负载均衡。

## 原理

- **haproxy**：TCP 负载均衡，可配置转发到后端 server 节点
- **keepalived**：通过 VRRP 提供 VIP 漂移

## 配置方式

使用静态配置文件，通过 `copy` 模块部署到目标主机。

**使用前请先替换 `files/` 目录中的 `__CHANGEME_*__` 占位符为实际值。**

### 文件结构

| 文件 | 目标路径 | 说明 |
|------|----------|------|
| `files/haproxy/haproxy.cfg` | `/etc/haproxy/haproxy.cfg` | HAProxy 主配置 |
| `files/haproxy/conf.d/00-default.cfg` | `/etc/haproxy/conf.d/00-default.cfg` | 统计页面 + 占位后端 |
| `files/haproxy/conf.d/01-web-ingress.cfg` | `/etc/haproxy/conf.d/01-web-ingress.cfg` | 业务流量转发（示例，默认注释） |
| `files/keepalived/keepalived.conf` | `/etc/keepalived/keepalived.conf` | Keepalived VRRP 配置 |

### 占位符说明

| 占位符 | 说明 | 示例 |
|--------|------|------|
| `__CHANGEME_hostname__` | 节点唯一标识 | `k3s-server-1` |
| `__CHANGEME_keepalived-vip__` | VIP 地址（含掩码） | `192.168.5.254/24` |
| `__CHANGEME_*__` | 其他自定义配置 | 按需替换 |

## 变量

| 变量 | 说明 | 示例 |
|------|------|------|
| `keepalived_vip` | Keepalived 虚拟 IP（文档记录，不使用模板注入） | `192.168.5.254/24` |

## 使用

```bash
# 使用前先替换 files/ 中的 __CHANGEME_*__ 占位符
# 然后运行:
bash run.sh lb
```

## 注意事项

- 前置条件：k3s server 已安装并运行在 `6443` 端口
- 替换 `__CHANGEME_*__` 占位符后，再执行 `bash run.sh lb`
- 独立于 k3s 安装流程，按需部署
