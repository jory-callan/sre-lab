# Cilium — eBPF CNI + Hubble 网络可视化

Cilium 是基于 eBPF 的 CNI 插件，提供网络、安全和可观测性功能。配合 Hubble 实现流量可视化。

## 架构位置

```
k3s-server-1 (249) ──┐
k3s-server-2 (101) ──┼── Cilium (eBPF) ── Pod 网络互通
k3s-server-3 (109) ──┘
      │
      └── Hubble Relay / UI ── 流量可视化
```

## 前置条件

- [x] k3s 集群已安装且 `flannel-backend: none`
- [x] Helm 和 kubectl 在控制节点可用（已由 k3s role 安装）
- [x] 节点间网络互通

## 部署

```bash
ssh k3s-server-1
cd /root/bootstrap
bash install.sh cilium
```

或从顶层入口：

```bash
bash /root/bootstrap/install.sh cilium
```

## 配置说明

| 参数 | 值 | 说明 |
|------|-----|------|
| 版本 | 1.16.6 | 稳定版 |
| kubeProxyReplacement | false | 保留 k3s 内置 kube-proxy |
| ipam.mode | cluster-pool | 自动分配 Pod CIDR |
| routingMode | native | 直接路由（k3s 集群内节点互通） |
| autoDirectNodeRoutes | true | 自动添加节点路由 |
| Hubble | enabled | 开启 Hubble 流量监控 + UI |

部署后 Pod CIDR 范围：`10.42.0.0/16`，每个节点分配 `/24`。

## 验证

```bash
# 检查 Cilium 状态
kubectl -n kube-system get pods -l k8s-app=cilium

# 检查节点状态（应变为 Ready）
kubectl get nodes

# 检查 Hubble UI（可选）
kubectl port-forward -n kube-system svc/hubble-ui 12000:80
# 浏览器访问 http://localhost:12000

# Cilium 自带检查
kubectl -n kube-system exec -it daemonset/cilium -- cilium status
```

### 预期输出

```
$ kubectl get nodes
NAME           STATUS   ROLES                       AGE   VERSION
k3s-server-1   Ready    control-plane,etcd,master   30m   v1.31.5+k3s1
k3s-server-2   Ready    control-plane,etcd,master   29m   v1.31.5+k3s1
k3s-server-3   Ready    control-plane,etcd,master   28m   v1.31.5+k3s1
```

## 清理

```bash
helm uninstall cilium -n kube-system

# 清理 CNI 配置残留
rm -f /var/lib/cni/networks/cilium/*
rm -f /etc/cni/net.d/*cilium*

# 清理 Cilium 内核状态（重启节点更彻底）
# reboot
```

## 注意事项

1. **首次安装等待 2-5 分钟** — Cilium 需要编译 eBPF 程序并下发到各节点
2. **kubeProxyReplacement=false** — k3s 有自己的 kube-proxy，与 Cilium 完全模式冲突
3. **bpf.masquerade=false** — 保留 iptables masquerade，避免 BPF 模式下的复杂排查
4. **system-default-registry 冲突** — k3s config.yaml 配置了阿里云镜像，Cilium 部分镜像可能需手动拉取
5. **卸载后重启节点** — 确保 CNI 和 iptables 规则完全清理

## 故障排查

| 现象 | 可能原因 | 解决 |
|------|---------|------|
| Pod 一直 Pending | CNI 未就绪 | 检查 `cilium status` |
| 节点 Ready 但 Pod 之间不通 | 路由未同步 | `autoDirectNodeRoutes=true` 是否生效 |
| Hubble 无流量 | Relay 未就绪 | 检查 hubble-relay pod 日志 |
| helm 安装报 "unknown authority" | kubeconfig CA 过期 | `cp /etc/rancher/k3s/k3s.yaml ~/.kube/config` |
