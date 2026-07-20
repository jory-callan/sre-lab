# Valkey 配置说明

## 配置模板

Valkey 配置由 KubeBlocks 通过 ConfigMap 管理，模板位于 `operators` 命名空间：

| 资源 | 名称 | 用途 |
|------|------|------|
| ConfigMap | `valkey-config-template` | Valkey 配置模板（`valkey.conf`） |
| ConfigMap | `valkey-scripts-template-0.1.1` | 启动/探针/切换脚本 |
| ParametersDefinition | `valkey8-pd` | valkey-8 参数定义与校验规则 |
| ParametersDefinition | `valkey9-pd` | valkey-9 参数定义与校验规则 |
| ConfigConstraint | `valkey-replication-config` | 配置约束（参数范围校验） |

## 配置模板内容

模板位于 `valkey-config-template`，渲染后挂载到 Pod 的 `/etc/conf/valkey.conf`。
启动脚本在此基础上追加动态参数（port、requirepass、replicaof 等）。

关键参数：

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `bind` | `* -::*` | 监听地址 |
| `port` | 6379 | 服务端口 |
| `appendonly` | yes | AOF 持久化 |
| `appendfsync` | everysec | AOF 刷盘策略 |
| `maxmemory` | 80% 容器内存 | 最大内存 |
| `maxmemory-policy` | allkeys-lru | 淘汰策略 |
| `io-threads` | 2 或 CPU 数 | IO 线程数 |
| `io-threads-do-reads` | yes | IO 多线程读 |
| `activedefrag` | yes | 主动碎片整理 |

## 查看配置

```bash
# 查看 Pod 中的配置文件
kubectl -n valkey exec valkey-valkey-0 -- cat /etc/conf/valkey.conf

# 查看渲染后的运行时配置
kubectl -n valkey exec valkey-valkey-0 -- valkey-cli -a valkey@czw123 CONFIG GET *
```

## 修改配置

直接编辑 ConfigMap，编辑后重启 Pod 使配置生效：

```bash
# 编辑配置模板
kubectl edit configmap valkey-config-template -n operators

# 重启 Pod 加载新配置
kubectl -n valkey rollout restart statefulset valkey-valkey
```

部分参数（如 `maxmemory`、`maxmemory-policy`）可通过 `valkey-cli CONFIG SET` 动态生效，无需重启。

## 可调参数参考

通过 `valkey8-pd` 查看完整的参数定义和校验规则：

```bash
kubectl get parametersdefinition valkey8-pd -o yaml
```

完整参数列表见 [Valkey 官方文档](https://valkey.io/topics/config/)。
