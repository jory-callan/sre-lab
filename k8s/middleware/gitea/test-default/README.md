# Gitea — 测试实例

轻量级自托管 Git 服务，SQLite + NFS 持久化，ingress-nginx 域名访问。

## 版本

| 组件 | 版本 |
|------|------|
| Gitea | 1.26.4 |
| Helm Chart | 12.6.0 |

## 访问

| 方式 | 地址 |
|------|------|
| Web | http://gitea.czw-sre.internal |
| Git (HTTP) | https://gitea.czw-sre.internal/\<user\>/\<repo\>.git |
| Git (SSH) | ssh://git@\<node-ip\>:30022/\<user\>/\<repo\>.git |
| NodePort HTTP | \<node-ip\>:30021 |
| 指标 | https://gitea.czw-sre.internal/metrics |

## 管理员

| 账号 | 密码 |
|------|------|
| admin | Admin@czw123 |

## 验证

```bash
kubectl -n gitea get pods
curl -s http://gitea-http.gitea:3000/api/healthz
# {"status":"pass"}
```
