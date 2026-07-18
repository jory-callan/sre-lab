# webhook2im — 测试实例

Webhook to IM — 接收 Webhook 事件并转发到即时通讯工具（飞书/钉钉/企业微信）。

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

## 路由

| 路径 | 用途 |
|------|------|
| /alertmanager | AlertManager 告警通知 → 飞书 |
| /health | 健康检查 |

## 测试

```bash
# 健康检查
curl -k https://webhook2im.czw-sre.internal/health

# 模拟 AlertManager 告警
curl -X POST https://webhook2im.czw-sre.internal/alertmanager \
  -H "Content-Type: application/json" \
  -d '{"status":"firing","alerts":[{"labels":{"alertname":"CPU高","severity":"critical"},"annotations":{"description":"CPU 超过 90%"},"startsAt":"2026-01-01T00:00:00Z"}]}'
```
