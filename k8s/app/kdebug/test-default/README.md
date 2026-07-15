# kdebug — 测试实例

K8s HTTP 调试 Pod，基于 Echo 框架。

## 版本

| 组件 | 版本 |
|------|------|
| kdebug | v1.0.2 |
| Helm Chart | 0.1.0 |

## 访问

| 方式 | 地址 |
|------|------|
| Web | https://kdebug.czw-sre.internal |
| NodePort | `<node-ip>:30302` |
| ClusterIP | kdebug.kdebug.svc.cluster.local:80 |

## 健康检查

```bash
curl -k https://kdebug.czw-sre.internal/ping
# 预期返回: pong
```
