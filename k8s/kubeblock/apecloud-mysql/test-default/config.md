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

## 查看当前配置

```bash
# 查看 Pod 中的配置文件
kubectl -n mysql exec apecloud-mysql-mysql-0 -- cat /etc/mysql/conf.d/my.cnf

# 查看运行时变量
kubectl -n mysql exec apecloud-mysql-mysql-0 -- mysql -uroot -proot@czw123 -e "SHOW VARIABLES;"
```

## 修改配置

通过 KubeBlocks 配置功能修改，不要直接编辑 ConfigMap：

```bash
# 查看可配置参数
kubectl get parametersdefinition apecloud-mysql8.0-pd -o yaml
```

## 可动态配置的参数

通过 `apecloud-mysql8.0-pd` 的 `dynamicParameters` 字段定义，修改后自动 reload 生效。
常见可动态配置参数：

- `max_connections`、`sql_mode`、`slow_query_log`、`long_query_time`
- `innodb_*` 相关参数
- `binlog_expire_logs_seconds`

## 相关文档

- [MySQL 8.0 配置文档](https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html)
- [ApeCloud MySQL 说明](https://github.com/apecloud/apecloud-mysql)
- [KubeBlocks 配置管理](https://kubeblocks.io/docs/user-docs/configuration/)
