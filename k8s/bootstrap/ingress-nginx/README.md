# ingress-nginx — Kubernetes Ingress Controller

ingress-nginx 是 Kubernetes 官方维护的 Ingress Controller，将外部 HTTP/HTTPS 流量路由到集群内 Service。

## 架构

|```
域名 (*.czw-sre.internal)
        │ DNS
        ▼
LoadBalancer IP (MetalLB 分配)     ← 入口单点（L2 模式）
        │
        ▼
ingress-nginx-controller (Service)
  externalTrafficPolicy: Local
        │
        ├── k3s-server-1 ──▶ DaemonSet Pod (本地处理)
        ├── k3s-server-2 ──▶ DaemonSet Pod (本地处理)
        └── k3s-server-3 ──▶ DaemonSet Pod (本地处理)

NodePort 30080/30443 也可直接访问任意节点 IP
```

## 前置条件

- [x] Cilium 网络已就绪
- [x] MetalLB 已安装并配置 IP 池
- [x] Helm 和 kubectl 可用

## 部署

```bash
ssh k3s-server-1
bash /root/bootstrap/install.sh ingress-nginx
```

### 获取 LoadBalancer IP

```bash
kubectl -n ingress-nginx get svc ingress-nginx-controller
# 输出示例:
# NAME                       TYPE           CLUSTER-IP    EXTERNAL-IP
# ingress-nginx-controller   LoadBalancer   10.43.x.x     192.168.5.200
```

将 `*.czw-sre.internal` 的 DNS 指向该 `EXTERNAL-IP`。

## 配置说明

| 参数 | 默认值 | 说明 |
|------|--------|------|
| controller.kind | DaemonSet | 每 Node 运行 Ingress pod，零丢包 + NodePort 任意节点可用 |
| controller.service.type | LoadBalancer | 通过 MetalLB 获取外部 IP（NodePort 30080/30443） |
| metrics.enabled | true | 暴露 Prometheus 指标 |
| compute-full-forwarded-for | true | 保留真实客户端 IP |
| proxy-body-size | 100m | 允许 100MB 请求体（大文件上传） |
| worker-processes | auto | 按 CPU 自动调整 Worker 数量 |

## 验证

```bash
# 检查 ingress-nginx pod
kubectl -n ingress-nginx get pods

# 检查分配的 External IP
kubectl -n ingress-nginx get svc ingress-nginx-controller

# 部署测试应用验证（配置文件在同级目录）
kubectl apply -f test-echo.yaml

# 测试（假设 EXTERNAL-IP 为 192.168.5.205）
curl -H "Host: echo.czw-sre.internal" http://192.168.5.205
# 应返回 nginx 欢迎页

# 清理测试
kubectl delete -f test-echo.yaml
```

## 清理

```bash
# 卸载 ingress-nginx
helm uninstall ingress-nginx -n ingress-nginx

# 清理命名空间
kubectl delete namespace ingress-nginx

# 清理测试资源
kubectl delete ingress test-echo
kubectl delete svc echo
kubectl delete deploy echo
```

## 注意事项

1. **MetalLB 必须先安装** — ingress-nginx 依赖 LoadBalancer IP
2. **DNS 配置** — 使用 `*.czw-sre.internal` 通配符域名，在 router 上做 DNS 解析指向 MetalLB IP
3. **Proxy Protocol** — 当前架构不需要（MetalLB L2 直接转发，中间无 L4 反代）
4. **SSL/TLS 终止** — 推荐在 nginx 层配置证书，用 cert-manager 自动管理
5. **保留真实客户端 IP** — 已启用 `compute-full-forwarded-for` + `use-forwarded-headers`，配合 `externalTrafficPolicy: Local` 可获得真实源 IP
6. **DaemonSet 优势** — 每 Node 都有 Ingress pod，MetalLB L2 leader 切换时零丢包；任意节点 NodePort 30080/30443 均可访问服务，不依赖 LB

## 故障排查

| 现象 | 可能原因 | 解决 |
|------|---------|------|
| EXTERNAL-IP 一直 Pending | MetalLB 未安装或 IP 池耗尽 | 检查 MetalLB 配置 |
| curl 返回 503 | Ingress 后端 Service 不存在或 Pod 不健康 | `kubectl describe ingress` |
| 504 Gateway Timeout | 上游响应超时 | 增加 `proxy-read-timeout` / `proxy-send-timeout` |
| 客户端 IP 全是 Cluster IP | externalTrafficPolicy 默认为 Cluster | 修改 Service 的 `externalTrafficPolicy: Local` |
| 日志不记录访问 | access-log 未启用 | 添加 `controller.config.log-format-upstream` 配置 |
