# k3s 5分钟快速上手指南

```
环境要求：
- 干净的 Linux 服务器（Ubuntu/Debian/CentOS/Alpine）
- 40G 系统盘 + 200G 数据盘（SSD 最好）
- 网络连通
```

---

## 场景 1：单节点开发环境（3步）

```bash
# 1. 赋予执行权限
chmod +x install-k3s.sh uninstall-k3s.sh

# 2. 安装（自动配置国内镜像源）
sudo ./install-k3s.sh

# 3. 验证
kubectl get nodes
```

完事！

---

## 场景 2：生产环境单节点（推荐）

### 前置检查
```bash
lsblk   # 确认数据盘设备，如 /dev/sdb
```

### 开始部署（4步）

```bash
# 1. 准备数据盘
vim prepare-data-disk.sh  # 编辑第一行 DISK_DEVICE="/dev/sdb"
sudo ./prepare-data-disk.sh

# 2. 用生产环境配置
cp examples/production/config.yaml .
vim config.yaml  # 修改 token 和 tls-san 部分

# 3. 安装
sudo ./install-k3s.sh

# 4. 验证
kubectl get nodes
df -h /data
```

---

## 场景 3：高可用集群（3 Server + N Agent）

### Node 1（第一个 Server）
```bash
sudo ./prepare-data-disk.sh
cp examples/production/config.yaml .
vim config.yaml  # cluster-init: true
sudo ./install-k3s.sh
cat /var/lib/rancher/k3s/server/token  # 记录 token
```

### Node 2、3（加入 Server）
```bash
sudo ./prepare-data-disk.sh
cp examples/production/config.yaml .
vim config.yaml  # 1. cluster-init: false
                  # 2. server: "https://<node1-ip>:6443"
                  # 3. token: "<复制上面的token>"
sudo ./install-k3s.sh
```

### Node 4+（Agent 节点）
```bash
sudo ./prepare-data-disk.sh
cp examples/agent/config.yaml .
vim config.yaml  # 1. server: "https://<node1-ip>:6443"
                  # 2. token: "<复制token>"
vim install-k3s.sh  # 修改 NODE_ROLE="agent"
sudo ./install-k3s.sh
```

---

## 日常维护

### 查看集群状态
```bash
kubectl get nodes
kubectl get pods -A
```

### ETCD 维护（每周运行一次）
```bash
sudo ./etcd-tool.sh status      # 查看状态
sudo ./etcd-tool.sh maintenance # 完整维护
sudo ./etcd-tool.sh backup      # 备份
```

### 重启 k3s
```bash
systemctl restart k3s
```

### 卸载（清空所有数据）
```bash
sudo ./uninstall-k3s.sh
```

---

## config.yaml 你需要修改的只有 3 处

```yaml
# 1. Token（所有节点保持一致）
token: "你的随机字符串"

# 2. 如果是加入集群的节点
cluster-init: false
server: "https://192.168.1.100:6443"

# 3. TLS 域名/IP（加上你的服务器 IP）
tls-san:
  - "k3s-server"
  - "192.168.1.100"  # 改成实际 IP
```

---

## 推荐配置清单

| 配置项 | 开发环境 | 生产环境 |
|--------|----------|----------|
| data-dir | 不配置 | /data/k3s |
| 数据盘 | 不需要 | SSD 200G+ |
| 日志限制 | 100Mi 5 files | 50Mi 3 files |
| ETCD 快照 | 6小时/次 | 3小时/次 |
| 高可用 | 单节点 | 3 Server |

---

## 遇到问题？

1. 查看 k3s 日志：`journalctl -u k3s -f`
2. 查看详细文档：`CONFIG-GUIDE.md`
3. 查看原始文档：`k3s.md`

---

**就这么简单！开始用吧！** 🚀
