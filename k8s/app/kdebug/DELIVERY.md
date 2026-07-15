# kdebug 交付详情

## 架构

```
用户 → curl -k https://kdebug.czw-sre.internal/ping
          │
          ▼
    ingress-nginx (cert-manager internal-ca)
          │
          ▼
    Service kdebug (ClusterIP :80)
          │
          ▼
    Deployment kdebug (2 副本)
          │
          ├── /ping   — 健康检查 + 返回 Pod 信息
          ├── /env    — 环境变量
          ├── /info   — 运行时信息
          └── /       — 404
```

## 端点

| 路径 | 说明 |
|------|------|
| `GET /ping` | 返回 `{"code":0,"msg":"pong"}` |
| `GET /env` | 返回 Pod 环境变量 |
| `GET /info` | 返回 Go 运行时信息 |

## 访问方式

| 方式 | 地址 | 用途 |
|------|------|------|
| 集群内 | `kdebug.kdebug.svc.cluster.local:80` | 微服务网络调试 |
| Ingress | `https://kdebug.czw-sre.internal` | 证书 / Ingress 调试 |
| NodePort | `<node-ip>:30302` | 无 DNS 场景验证 |
| 本地转发 | `kubectl -n kdebug port-forward svc/kdebug 8080:80` | 本地调试 |

## 证书

Ingress 通过 `cert-manager.io/cluster-issuer: internal-ca` 自动签发：

```
selfsigned-ca → ca-root → internal-ca → kdebug-tls
```

验证：

```bash
# 查看证书
kubectl -n kdebug get certificate
kubectl -n kdebug get secret kdebug-tls -o yaml
```

## 自动伸缩

| 配置 | 值 |
|------|-----|
| minReplicas | 2 |
| maxReplicas | 5 |
| 触发条件 | CPU > 70% |
| PDB | minAvailable: 1（最多允许 1 副本不可用） |

## 反亲和

Pod 分散到不同节点（preferred），避免调试时单点集中。

## 验证场景

| 场景 | 命令 |
|------|------|
| Ingress HTTPS | `curl -k https://kdebug.czw-sre.internal/ping` |
| 内部 DNS | `kubectl run test --image=busybox -it --rm -- wget -qO- kdebug.kdebug.svc:80/ping` |
| NodePort | `curl -s http://192.168.5.107:30302/ping` |
| HPA 验证 | `kubectl -n kdebug get hpa` |
| 证书 | `openssl s_client -connect kdebug.czw-sre.internal:443 -showcerts` |
