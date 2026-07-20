# ApeCloud MySQL 配置说明

## 配置模板

ApeCloud MySQL 配置由 KubeBlocks 通过 ConfigMap 管理，模板位于 `operators` 命名空间：

| 资源 | 名称 | 用途 |
|------|------|------|
| ConfigMap | `mysql8.0-config-template` | MySQL 8.0 配置模板（`my.cnf`） |
| ConfigMap | `apecloud-mysql-scripts` | 启动/探针/切换脚本 |
| ConfigMap | `mysql-reload-script` | 动态 reload 脚本 |
| ParametersDefinition | `apecloud-mysql8.0-pd` | 参数定义与校验规则 |

## 配置模板内容

模板位于 `mysql8.0-config-template`，渲染后挂载到 Pod 的 `/etc/mysql/conf.d/my.cnf`。
启动脚本在此基础上追加动态参数。

关键参数：

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `port` | 3306 | 服务端口 |
| `innodb_buffer_pool_size` | 75% 容器内存 | InnoDB 缓冲池 |
| `max_connections` | 按内存自动计算 | 最大连接数 |
| `gtid_mode` | ON | GTID 模式 |
| `binlog_format` | ROW | 二进制日志格式 |
| `binlog_expire_logs_seconds` | 604800 | 日志保留时间（7天） |
| `slow_query_log` | ON | 慢查询日志 |
| `long_query_time` | 5 | 慢查询阈值（秒） |
| `authentication_policy` | `mysql_native_password,` | 认证插件 |
| `slave_exec_mode` | IDEMPOTENT | 复制冲突处理 |

## 查看配置

```bash
# 查看 Pod 中的配置文件
kubectl -n mysql exec apecloud-mysql-mysql-0 -- cat /etc/mysql/conf.d/my.cnf

# 查看运行时变量
kubectl -n mysql exec apecloud-mysql-mysql-0 -- mysql -uroot -proot@czw123 -e "SHOW VARIABLES;"
```

## 修改配置

直接编辑 ConfigMap，编辑后重启 Pod 使配置生效：

```bash
# 编辑配置模板
kubectl edit configmap mysql8.0-config-template -n operators

# 重启 Pod 加载新配置
kubectl -n mysql rollout restart statefulset apecloud-mysql-mysql
```

部分参数（如 `max_connections`、`slow_query_log`）可通过 `SET GLOBAL` 动态生效，无需重启。

## 可调参数参考

通过 `apecloud-mysql8.0-pd` 查看完整的参数定义和校验规则：

```bash
kubectl get parametersdefinition apecloud-mysql8.0-pd -o yaml
```

完整参数列表见 [MySQL 8.0 官方文档](https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html)。
