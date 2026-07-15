# MinIO Operator v5.0.18

版本锁定说明：不再主动升级，除非有严重安全漏洞需要修补。Operator v5.x 最后一个版本，配合 MinIO RELEASE.2025-04-22（最后一个完整 WebUI 版本）使用。

## 版本

| 组件 | 版本 |
|------|------|
| MinIO Operator | v5.0.18 |
| Helm Chart | 5.0.18 |

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
