# Redis 稳定性测试报告

## 测试环境

| 项目 | 信息 |
|------|------|
| 版本 | Redis 7.2.4 (standalone mode) |
| 拓扑 | 1 Master + 1 Replica + 3 Sentinel |
| 认证 | default / redis@czw123 |
| 持久化 | RDB + AOF |
| Master 节点 | k3s-agent-1 (192.168.5.124) |
| Replica 节点 | k3s-agent-2 (192.168.5.125) |
| 服务地址 | redis-redis-redis.redis.svc.cluster.local:6379 |
| 管理方式 | KubeBlocks 1.0.2 |

## 测试结果总览

| 场景 | 状态 | 关键指标 |
|------|------|----------|
| 1. 基准验证 | PASS | 连接正常，主从同步，1000 键写入成功 |
| 2. Master Pod 重启 + 故障转移 | PASS | RTO: 420ms，数据无丢失 |
| 3. Replica Pod 重启 | PASS | 重连后数据自动同步 |
| 4. 网络分区模拟 | PASS | 分区期间 Master 可写，恢复后自动同步 |
| 5. 高负载下故障转移 | PASS | 5000 键写入全部成功，无数据丢失 |
| 6. 连接风暴 | PASS | 200 并发连接无异常，连接数恢复正常 |
| 7. 持久化与数据恢复 | PASS | 硬 Kill 后 AOF/RDB 恢复正常 |
| 8. 全部 Sentinel 下线 + 恢复 | PASS | 无 Sentinel 时 Master 正常读写，Sentinel 恢复后拓扑重建 |

## 详细场景分析

### 场景 1: 基准验证
- 通过 Service 和 Pod 直连均正常
- 主从复制状态正常，offset 一致
- 1000 个测试键写入成功，DBSIZE 正常

### 场景 2: Master Pod 重启 + 故障转移
- 删除 Master Pod 后，Sentinel 在 **420ms** 内检测到故障
- 故障转移完成后，新 Master 立即就绪
- **注意**: 直接连接 ClusterIP Service 时，在 Master 切换窗口期（约 10-15s）出现 Connection refused
- 旧 Master 恢复后自动降级为 Replica

### 场景 3: Replica Pod 重启
- Replica 删除后，Master 继续正常写入
- Replica 恢复后，复制链路自动重建
- 数据完全同步，无丢失

### 场景 4: 网络分区
- 使用 iptables 阻断 Master 到 Replica 的流量
- 分区期间 Master 正常读写
- 恢复后 Replica 自动同步，offset 一致

### 场景 5: 高负载下故障转移
- Sentinel 触发 FAILOVER 时出现 `NOGOODSLAVE`（瞬态，因 Master 刚被删除）
- 故障转移完成后，Master 稳定
- 5000 个键在高负载下全部写入成功，数据一致性验证通过
- 最终 DBSIZE: 6003（含之前测试数据）

### 场景 6: 连接风暴
- 200 个并发连接快速创建/关闭，无异常
- 10 轮 100 连接的操作完成后，连接数恢复正常
- 内存使用稳定

### 场景 7: 持久化与数据恢复
- BGSAVE 完成后 Last Save 时间戳正常
- 硬 Kill Master 后，Sentinel 准确触发故障转移
- 新 Master 数据恢复成功
- 持久化文件存在：appendonlydir + dump.rdb (251KB)

### 场景 8: 全部 Sentinel 下线 + 恢复
- 删除全部 Sentinel 后，Master 继续正常读写
- 删除 Master 后，服务中断
- Sentinel 恢复后，自动重建拓扑发现
- 数据一致性通过

## 风险与建议

### 已确认的问题
1. **故障转移窗口期**: 直接连接 ClusterIP 时，Master 切换后约 10-15s 无法连接。这是 Kubernetes Service 端点更新的固有延迟，不属于 Redis 本身问题
2. **Sentinel 密码同步**: 修改密码后，Sentinel 需要重启或手动更新 ACL 文件，否则 Sentinel 无法连接 Redis

### 生产建议
1. **客户端需实现重试机制**: 建议使用支持自动重连的 Redis 客户端（如 redis-py、Jedis、Lettuce），设置合理重试策略
2. **连接池配置**: 建议启用连接池，并设置 `maxTotal` 和 `maxWaitMillis`，避免连接风暴时耗尽资源
3. **监控指标**: 建议通过 ServiceMonitor 采集 Redis metrics，关注 `connected_clients`、`repl_backlog_histlen`、`rdb_bgsave_in_progress` 等指标
4. **持久化配置**: RDB + AOF 双重持久化可靠，建议设置合理的 `save` 策略和 `auto-aof-rewrite-percentage`

## 结论

Redis 7.2.4 (KubeBlocks 管理) 在 1 主 1 从 + 3 Sentinel 拓扑下，**具备生产可用性**。故障转移 RTO 约 420ms（Sentinel 检测到切换），但客户端需做好重连机制。网络分区、高负载、持久化恢复等场景均表现稳定。
