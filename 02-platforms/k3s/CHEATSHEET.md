# k3s 速查表 Cheat Sheet

## 一、安装命令

| 目标 | 命令 |
|------|------|
| 单节点开发环境 | `sudo ./install-k3s.sh` |
| 生产环境单节点 | 1. `sudo ./prepare-data-disk.sh` <br> 2. 编辑 `config.yaml` <br> 3. `sudo ./install-k3s.sh` |
| 加入集群 (Server) | 编辑 `config.yaml` 中的 `server` 和 `token` <br> `sudo ./install-k3s.sh` |
| 加入集群 (Agent) | 编辑 `install-k3s.sh` 中的 `NODE_ROLE="agent"` <br> `sudo ./install-k3s.sh` |

---

## 二、配置文件

| 文件 | 位置 | 说明 |
|------|------|------|
| config.yaml | /etc/rancher/k3s/ | k3s 主配置 |
| registries.yaml | /etc/rancher/k3s/ | 镜像源配置 |
| kubelet.config.yaml | /etc/rancher/k3s/ | kubelet 详细配置（可选） |

---

## 三、日常操作

| 功能 | 命令 |
|------|------|
| 查看节点 | `kubectl get nodes` |
| 查看所有 Pod | `kubectl get pods -A` |
| 查看 k3s 状态 | `systemctl status k3s` |
| 查看 k3s 日志 | `journalctl -u k3s -f` |
| 重启 k3s | `systemctl restart k3s` |
| 查看 Token | `cat /var/lib/rancher/k3s/server/token` |

---

## 四、ETCD 维护

| 功能 | 命令 |
|------|------|
| 查看状态 | `sudo ./etcd-tool.sh status` |
| 完整维护 | `sudo ./etcd-tool.sh maintenance` |
| 备份 | `sudo ./etcd-tool.sh backup` |
| 碎片整理 | `sudo ./etcd-tool.sh defrag` |
| 解除告警 | `sudo ./etcd-tool.sh alarm` |

---

## 五、config.yaml 最小配置

```yaml
# ========== 第一个 Server 节点 ==========
cluster-init: true
token: "你的随机字符串"
data-dir: "/data/k3s"

tls-san:
  - "192.168.1.100"  # 你的服务器 IP

# ========== 加入的节点 ==========
cluster-init: false
server: "https://192.168.1.100:6443"
token: "与上面相同的token"
data-dir: "/data/k3s"
```

---

## 六、生产环境检查清单

- [ ] 数据盘已挂载到 /data
- [ ] 已运行 prepare-data-disk.sh
- [ ] config.yaml 中 data-dir: "/data/k3s"
- [ ] token 是强随机字符串
- [ ] tls-san 包含了所有节点 IP
- [ ] etcd 数据在 SSD 上
- [ ] 已配置时间同步

---

## 七、常用组件安装

### ingress-nginx
```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  -n ingress-nginx --create-namespace \
  --set controller.image.registry=registry.cn-hangzhou.aliyuncs.com \
  --set controller.image.image=google_containers/nginx-ingress-controller \
  --set controller.image.tag=v1.13.2 \
  --set controller.image.digest="" \
  --set controller.kind=DaemonSet \
  --set controller.hostNetwork=true \
  --set controller.service.enabled=false
```

---

## 八、故障排查

| 现象 | 排查命令 |
|------|----------|
| 节点 NotReady | `kubectl describe node <node-name>` |
| Pod 启动失败 | `kubectl describe pod <pod-name> -n <namespace>` |
| k3s 启动失败 | `journalctl -u k3s -n 50` |
| 磁盘满 | `df -h` / `docker system prune -a` |

---

## 九、卸载

```bash
sudo ./uninstall-k3s.sh
```

---

**更多文档：**
- QUICKSTART.md - 5分钟快速上手指南
- README.md - 完整文档
- CONFIG-GUIDE.md - 配置详解
- examples/ - 配置示例
