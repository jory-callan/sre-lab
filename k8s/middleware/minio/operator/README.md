# MinIO Operator v5.0.18

版本锁定说明：不再主动升级，除非有严重安全漏洞需要修补。Operator v5.x 最后一个版本，配合 MinIO RELEASE.2025-04-22（最后一个完整 WebUI 版本）使用。

## 版本

| 组件 | 版本 |
|------|------|
| MinIO Operator | v5.0.18 |
| Helm Chart | 5.0.18 |

## 访问

| 位置 | 地址 |
|------|------|
| 集群外部 | `https://minio-operator.czw-sre.internal`（或 `http://minio-operator.czw-sre.internal`） |

## 部署

```bash
bash install.sh install
```

## 卸载

仅卸载 operator，保留 tenant：
```bash
bash install.sh uninstall
```

完全清理：
```bash
bash install.sh purge
```

## Ingress 配置说明

Operator Console Ingress 配置在 `ingress.yaml`，通过 annotation 控制行为：

```yaml
annotations:
  nginx.ingress.kubernetes.io/ssl-redirect: "false"  # 同时支持 HTTP + HTTPS
```

| 模式 | annotation 值 | 效果 |
|------|-------------|------|
| HTTP + HTTPS 双栈 | `ssl-redirect: "false"` | HTTP 和 HTTPS 都正常工作 |
| 仅 HTTPS | 删除该 annotation（或设为 `"true"`） | HTTP 请求被 301 重定向到 HTTPS |
