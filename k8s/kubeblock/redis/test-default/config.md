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
| `save` | 动态 | RDB 快照策略 |

## 查看当前配置

```bash
# 查看 Pod 中的配置文件
kubectl -n redis exec redis-redis-0 -- cat /etc/conf/redis.conf

# 查看渲染后的运行时配置
kubectl -n redis exec redis-redis-0 -- redis-cli -a redis@czw123 CONFIG GET *
```

## 修改配置

通过 KubeBlocks 配置功能修改，不要直接编辑 ConfigMap：

```bash
# 查看可配置参数
kubectl get parametersdefinition redis7-config-pd -o yaml

# 通过 KubeBlocks OpsRequest 修改（示例）
# kubectl apply -f ops-reconfigure.yaml
```

## 相关文档

- [Redis 配置文档](https://redis.io/docs/latest/operate/oss_and_stack/management/config/)
- [KubeBlocks 配置管理](https://kubeblocks.io/docs/user-docs/configuration/)
