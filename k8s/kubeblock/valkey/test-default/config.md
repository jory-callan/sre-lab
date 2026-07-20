# Valkey 配置说明

## 实例配置文件

实例专属配置位于 `config-instance.yaml`，已去除 Go 模板语法，直接编辑即可生效：

```bash
# 编辑配置
vim config-instance.yaml

# 应用到集群
kubectl apply -f config-instance.yaml -n operators

# 重启 Pod 加载新配置
kubectl -n valkey rollout restart statefulset valkey-valkey
```

> 配置在 git 中跟随实例版本管理，部署时应用对应版本的配置。

## 配置来源

| 资源 | 名称 | 说明 |
|------|------|------|
| ConfigMap | `valkey-config-template` (`operators`) | Valkey 配置模板 |
| ParametersDefinition | `valkey8-pd` | valkey-8 参数定义 |
| ConfigConstraint | `valkey-replication-config` | 配置约束（参数范围校验） |

## 关键参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `bind` | `* -::*` | 监听地址 |
| `port` | 6379 | 服务端口 |
| `appendonly` | yes | AOF 持久化 |
| `appendfsync` | everysec | AOF 刷盘策略 |
| `maxmemory-policy` | allkeys-lru | 淘汰策略 |
| `io-threads` | 4 | IO 线程数 |
| `activedefrag` | yes | 主动碎片整理 |

## 查看配置

```bash
# 查看 Pod 中的配置文件
kubectl -n valkey exec valkey-valkey-0 -- cat /etc/conf/valkey.conf

# 查看运行时参数
kubectl -n valkey exec valkey-valkey-0 -- valkey-cli -a valkey@czw123 CONFIG GET *
```

## 参数参考

```bash
kubectl get parametersdefinition valkey8-pd -o yaml
```

完整参数列表见 [Valkey 官方文档](https://valkey.io/topics/config/)。
