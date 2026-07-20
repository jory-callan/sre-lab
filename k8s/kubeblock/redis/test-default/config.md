# Redis 配置说明

## 配置模板

Redis 配置由 KubeBlocks 通过 ConfigMap 管理，模板位于 `operators` 命名空间：

| 资源 | 名称 | 用途 |
|------|------|------|
| ConfigMap | `redis7-config-template-1.0.2` | Redis 7.2 配置模板（`redis.conf`） |
| ConfigMap | `redis-scripts-template-1.0.2` | 启动/探针/切换脚本 |
| ConfigMap | `redis-metrics-config` | 指标采集配置 |
| ParametersDefinition | `redis7-config-pd` | 参数定义与校验规则 |

## 配置模板内容

模板位于 `redis7-config-template-1.0.2`，渲染后挂载到 Pod 的 `/etc/conf/redis.conf`。
启动脚本在此基础上追加动态参数（port、requirepass、replicaof 等）。

关键参数：

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `bind` | `* -::*` | 监听地址 |
| `port` | 6379 | 服务端口 |
| `appendonly` | yes | AOF 持久化 |
| `appendfsync` | everysec | AOF 刷盘策略 |
| `maxmemory` | 80% 容器内存 | 最大内存 |
| `maxmemory-policy` | volatile-lru | 淘汰策略 |
| `io-threads` | 4 | IO 线程数 |
| `io-threads-do-reads` | yes | IO 多线程读 |

## 查看配置

```bash
# 查看 Pod 中的配置文件
kubectl -n redis exec redis-redis-0 -- cat /etc/conf/redis.conf

# 查看渲染后的运行时配置
kubectl -n redis exec redis-redis-0 -- redis-cli -a redis@czw123 CONFIG GET *
```

## 修改配置

直接编辑 ConfigMap，编辑后重启 Pod 使配置生效：

```bash
# 编辑配置模板
kubectl edit configmap redis7-config-template-1.0.2 -n operators

# 重启 Pod 加载新配置
kubectl -n redis rollout restart statefulset redis-redis
```

部分参数（如 `maxmemory`、`maxmemory-policy`）可通过 `redis-cli CONFIG SET` 动态生效，无需重启。

## 可调参数参考

通过 `redis7-config-pd` 查看完整的参数定义和校验规则：

```bash
kubectl get parametersdefinition redis7-config-pd -o yaml
```

完整参数列表见 [Redis 官方文档](https://redis.io/docs/latest/operate/oss_and_stack/management/config/)。
