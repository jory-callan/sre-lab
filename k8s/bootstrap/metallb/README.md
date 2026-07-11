# MetalLB — 裸机 LoadBalancer

MetalLB 为裸机 Kubernetes 集群提供 LoadBalancer 类型的 Service 实现，解决 k3s 禁用内置 servicelb 后无法获取外部 IP 的问题。

## 架构

```
Service (type: LoadBalancer)
        │
        ▼
MetalLB Controller ─── 分配 IP
MetalLB Speaker   ─── 宣告路由 (L2 / BGP)
        │
        ▼
外部请求 → 节点 IP:NodePort → Pod
```

当前使用 **L2 模式**（无需 BGP 路由器），适合实验室/测试环境。

## 前置条件

- [x] Cilium 或其它 CNI 已就绪（确保 Pod 网络正常）
- [x] Helm 和 kubectl 可用

## 部署

```bash
ssh k3s-server-1
bash /root/bootstrap/install.sh metallb
```

### 配置 IP 地址池

安装后需要创建 IP 地址池和 L2 宣告配置。配置文件在同级目录下：

```bash
# 根据你内网实际空闲 IP 修改 pool.yaml 中的地址段
vim pool.yaml

kubectl apply -f pool.yaml
```

> **⚠️ IP 地址范围必须用你内网空闲段！** 当前配置 `192.168.5.205-192.168.5.209`，请根据实际网络调整。

## 验证

```bash
# 检查 MetalLB 组件
kubectl -n metallb-system get pods

# 创建一个测试 Service 看是否分配到 IP
kubectl create deploy test-lb --image nginx:alpine
kubectl expose deploy test-lb --name test-lb-svc --type LoadBalancer --port 80
kubectl get svc test-lb-svc
# 预期 EXTERNAL-IP 为池中某个 IP（如 192.168.5.200）
```

### 预期输出

```
$ kubectl -n metallb-system get pods
NAME                          READY   STATUS    RESTARTS   AGE
metallb-controller-xxxxx      1/1     Running   0          1m
metallb-speaker-xxxxx         1/1     Running   0          1m
metallb-speaker-yyyyy         1/1     Running   0          1m
metallb-speaker-zzzzz         1/1     Running   0          1m

$ kubectl get svc test-lb-svc
NAME          TYPE           CLUSTER-IP    EXTERNAL-IP     PORT(S)        AGE
test-lb-svc   LoadBalancer   10.43.x.x     192.168.5.200   80:3xxxx/TCP   30s
```

## 配置参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| IP 池范围 | 192.168.5.200-192.168.5.220 | 根据内网实际情况修改 |
| 模式 | L2 | L2（ARP/NDP）无需路由器支持 |
| 协议 | 静态 IP 池 | 无需 DHCP 预留 |

## 清理

```bash
# 卸载 MetalLB
helm uninstall metallb -n metallb-system

# 清理 CRD
kubectl delete crd ipaddresspools.metallb.io
kubectl delete crd l2advertisements.metallb.io
kubectl delete crd bgppeers.metallb.io
kubectl delete crd communities.metallb.io
kubectl delete crd bgpadvertisements.metallb.io

# 清理命名空间
kubectl delete namespace metallb-system

# 清理测试服务
kubectl delete svc test-lb-svc
kubectl delete deploy test-lb
```

## 注意事项

1. **IP 范围必须互斥** — 不同 IPAddressPool 不能重叠
2. **L2 模式下单 IP 单点** — 所有流量经过 Leader Speaker 节点，带宽受单节点限制
3. **避免与 DHCP 冲突** — 确保 IP 池不在 DHCP 自动分配范围内
4. **Speaker 使用 hostNetwork** — 需要 hostNetwork 权限来响应 ARP 请求

## 故障排查

| 现象 | 可能原因 | 解决 |
|------|---------|------|
| Service EXTERNAL-IP 一直 Pending | IP 池未正确配置 | `kubectl describe IPAddressPool -n metallb-system` |
| Service 分配到 IP 但无法访问 | ARP 冲突或 L2 宣告缺失 | 检查 L2Advertisement 资源 |
| 多个 Service 竞争同 IP | IP 池 IP 用尽 | 扩大 IP 范围或回收未使用的 Service |
| Speaker 日志报错 | 节点间网络问题 | `kubectl -n metallb-system logs daemonset/metallb-speaker` |
