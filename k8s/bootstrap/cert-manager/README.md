# cert-manager — Kubernetes 证书生命周期管理

cert-manager 自动签发和续期 TLS 证书，为 Ingress 提供 HTTPS 支持。

## 架构

```
Ingress (TLS 配置)
    │ cert-manager 自动注入
    ▼
Certificate ── CertificateRequest ── Order ── Challenge (HTTP01/DNS01)
    │                                                   │
    │                                          Let's Encrypt / 其他 ACME CA
    ▼
Secret (tls.key + tls.crt)
    │
    ▼
Ingress 使用 Secret 提供 HTTPS
```

## 前置条件

- [x] kubectl 连接正常
- [x] Helm 可用
- [ ] (可选) ingress-nginx — 如需 HTTP01 挑战

## 部署

```bash
ssh k3s-server-1
bash /root/bootstrap/install.sh cert-manager
```

### 配置证书签发 (post-install)

```bash
# 根据你的环境编辑 cluster-issuer.yaml 中的 solvers
# 内网环境推荐 DNS01, 有公网 LB 推荐 HTTP01
kubectl apply -f /root/bootstrap/cert-manager/cluster-issuer.yaml
```

### 验证

```bash
# 检查 pod 状态
kubectl -n cert-manager get pods

# 检查 CRD 已注册
kubectl get crd | grep cert-manager

# 验证 ClusterIssuer 就绪
kubectl get clusterissuer letsencrypt-prod

# 测试签发 (创建测试证书)
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-cert
  namespace: default
spec:
  dnsNames:
    - test.czw-sre.internal
  issuerRef:
    kind: ClusterIssuer
    name: letsencrypt-prod
  secretName: test-cert-tls
EOF

# 查看证书状态
kubectl describe certificate test-cert
# 清理测试
kubectl delete certificate test-cert
```

## 配置说明

| 参数 | 默认值 | 说明 |
|------|--------|------|
| crds.enabled | false | 自动安装 CRD (设为 true) |
| webhook.timeoutSeconds | 30 | Webhook 超时 |

## Ingress TLS 集成示例

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"   # 自动签发
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - my-app.czw-sre.internal
      secretName: my-app-tls                              # cert-manager 自动创建
  rules:
    - host: my-app.czw-sre.internal
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 80
```

## 常见 Issuer 策略

| 方式 | 适用场景 | 前置条件 |
|------|----------|----------|
| **HTTP01** | 有公网 IP，域名公网可解析 | ingress-nginx，公网 MetalLB IP |
| **DNS01** | 内网环境、无公网 IP | DNS 服务商 API Token (Cloudflare/阿里云 DNSPod 等) |
| **SelfSigned** | 测试/POC | 无需外部依赖 |

## 清理

```bash
helm uninstall cert-manager -n cert-manager
kubectl delete namespace cert-manager
kubectl get crd | grep cert-manager | awk '{print $1}' | xargs kubectl delete crd
```

## 注意事项

1. **Let's Encrypt 速率限制** — 生产环境每周 50 张证书，测试用 staging issuer
2. **HTTP01 需要公网可达** — 内网环境只能用 DNS01 或自建 CA
3. **ClusterIssuer vs Issuer** — ClusterIssuer 是集群全局的，Issuer 只能用于单个命名空间
4. **证书自动续期** — cert-manager 在证书到期前 30 天自动续期

## 故障排查

| 现象 | 可能原因 | 解决 |
|------|---------|------|
| Certificate 一直 Ready=False | HTTP01 无法从公网访问 | 检查 DNS 解析和防火墙; 或改用 DNS01 |
| Order 状态 stuck | ACME 验证未通过 | `kubectl describe order` 查看详细原因 |
| Secret 未生成 | 签发过程失败 | `kubectl describe certificaterequest` 看 issue 日志 |
| issuer 找不到 | ClusterIssuer 名称配置错误 | `kubectl get clusterissuer` 确认名称和状态 |
