# Redis 配置说明

## 实例配置文件

实例专属配置位于 `config-instance.yaml`，已去除 Go 模板语法，直接编辑即可生效：

```bash
# 编辑配置
vim config-instance.yaml

# 应用到集群
kubectl apply -f config-instance.yaml -n operators

# 重启 Pod 加载新配置
kubectl -n redis rollout restart statefulset redis-redis
```

> 配置在 git 中跟随实例版本管理，部署时应用对应版本的配置。

## 配置来源

| 资源 | 名称 | 说明 |
|------|------|------|
| ConfigMap | `redis7-config-template-1.0.2` (`operators`) | Redis 配置模板 |
| ParametersDefinition | `redis7-config-pd` | 参数定义与校验规则 |

## 关键参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `bind` | `* -::*` | 监听地址 |
| `port` | 6379 | 服务端口 |
| `appendonly` | yes | AOF 持久化 |
| `appendfsync` | everysec | AOF 刷盘策略 |
| `maxmemory-policy` | volatile-lru | 淘汰策略 |
| `io-threads` | 4 | IO 线程数 |

## 查看配置

```bash
# 查看 Pod 中的配置文件
kubectl -n redis exec redis-redis-0 -- cat /etc/conf/redis.conf

# 查看运行时参数
kubectl -n redis exec redis-redis-0 -- redis-cli -a redis@czw123 CONFIG GET *
```

部分参数（如 `maxmemory-policy`）可通过 `CONFIG SET` 动态生效，无需重启。

## 参数参考

```bash
kubectl get parametersdefinition redis7-config-pd -o yaml
```

完整参数列表见 [Redis 官方文档](https://redis.io/docs/latest/operate/oss_and_stack/management/config/)。
