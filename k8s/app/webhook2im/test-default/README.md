# webhook2im — 测试实例

Webhook to IM — 接收 Webhook 事件并转发到即时通讯工具。

## 版本

| 组件 | 版本 |
|------|------|
| webhook2im | 0.1.0 |
| Helm Chart | 0.1.0 |

## 访问

| 方式 | 地址 |
|------|------|
| Web | https://webhook2im.czw-sre.internal |
| ClusterIP | webhook2im.webhook2im.svc.cluster.local:80 |

## 健康检查

```bash
curl -k https://webhook2im.czw-sre.internal/health
```
