# ApeCloud MySQL 配置说明

## 实例配置文件

实例专属配置位于 `config-instance.yaml`，直接编辑即可生效：

```bash
# 编辑配置
vim config-instance.yaml

# 应用到集群
kubectl apply -f config-instance.yaml -n operators

# 重启 Pod 加载新配置
kubectl -n mysql rollout restart statefulset apecloud-mysql-mysql
```

> 配置在 git 中跟随实例版本管理，部署时应用对应版本的配置。

## 配置来源

| 资源 | 名称 | 说明 |
|------|------|------|
| ConfigMap | `mysql8.0-config-template` (`operators`) | MySQL 8.0 配置模板 |
| ParametersDefinition | `apecloud-mysql8.0-pd` | 参数定义与校验规则 |

## 关键参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `port` | 3306 | 服务端口 |
| `innodb_buffer_pool_size` | 1G | InnoDB 缓冲池 |
| `max_connections` | 200 | 最大连接数 |
| `gtid_mode` | ON | GTID 模式 |
| `binlog_format` | ROW | 二进制日志格式 |
| `binlog_expire_logs_seconds` | 604800 | 日志保留时间（7天） |
| `slow_query_log` | ON | 慢查询日志 |
| `long_query_time` | 5 | 慢查询阈值（秒） |

## 查看配置

```bash
# 查看 Pod 中的配置文件
kubectl -n mysql exec apecloud-mysql-mysql-0 -- cat /etc/mysql/conf.d/my.cnf

# 查看运行时变量
kubectl -n mysql exec apecloud-mysql-mysql-0 -- mysql -uroot -proot@czw123 -e "SHOW VARIABLES;"
```

## 参数参考

```bash
kubectl get parametersdefinition apecloud-mysql8.0-pd -o yaml
```

完整参数列表见 [MySQL 8.0 官方文档](https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html)。
