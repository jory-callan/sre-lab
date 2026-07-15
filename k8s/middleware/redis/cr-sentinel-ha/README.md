# Redis Sentinel HA 实例

基于 spotahome/redisoperator 的 Redis Sentinel 高可用架构。

## 部署

```bash
bash install.sh install
```

## 访问
- 服务：`rfs-<name>.<namespace>.svc`
- 端口：6379（Redis）、26379（Sentinel）
