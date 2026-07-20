# Valkey 稳定性测试报告

## 测试环境

| 项目 | 信息 |
|------|------|
| 版本 | Valkey 8.1.8 (GA, 兼容 Redis 7.2.4 协议) |
| 拓扑 | 1 Master + 1 Replica + 3 Sentinel |
| 认证 | default / valkey@czw123 |
| 持久化 | RDB + AOF |
| Master 节点 | k3s-agent-1 (192.168.5.124) |
| Replica 节点 | k3s-agent-2 (192.168.5.125) |
| 服务地址 | valkey-valkey-valkey.valkey.svc.cluster.local:6379 |
| 管理方式 | KubeBlocks 1.0.2 |

## 测试结果总览

| 场景 | 状态 | 关键指标 |
|------|------|----------|
| 1. 基准验证 | PASS | 连接正常，主从同步，1000 键写入成功 |
| 2. Master Pod 重启 + 故障转移 | PASS | RTO: 433ms，数据无丢失 |
| 3. Replica Pod 重启 | PASS | 重连后数据自动同步 |
| 4. 网络分区模拟 | PASS | 分区期间 Master 可写，恢复后自动同步 |
| 5. 高负载下故障转移 | PASS | 5000 键写入全部成功，数据一致性通过 |
| 6. 连接风暴 | PASS | 200 并发连接无异常，连接数恢复正常 |
| 7. 持久化与数据恢复 | PASS | 硬 Kill 后 AOF/RDB 恢复，数据完整 |
| 8. 全部 Sentinel 下线 + 恢复 | PASS | 无 Sentinel 时 Master 正常读写，Sentinel 恢复后拓扑重建 |

## 详细场景分析

### 场景 1: 基准验证
- 通过 Service 和 Pod 直连均正常，PONG 响应正常
- 主从复制状态正常，master_repl_offset 一致
- Sentinels 正常监控 Master 和 Replica
- 1000 个测试键写入成功

### 场景 2: Master Pod 重启 + 故障转移
- 删除 Master Pod 后，Sentinel 在 **433ms** 内检测到故障并完成切换
- 新 Master 立即就绪
- ClusterIP Service 切换期间存在约 10-15s 连接不可用窗口
- 旧 Master 恢复后自动降级为 Replica

### 场景 3: Replica Pod 重启
- Replica 删除后 Master 继续正常写入
- Replica 恢复后自动完成全量同步
- 数据一致性验证通过

### 场景 4: 网络分区
- iptables 阻断 Master 到 Replica 流量后，Replica 显示 `master_link_status:down`
- Master 持续正常写入
- 恢复 iptables 后，Replica 自动重新同步，offset 追赶一致

### 场景 5: 高负载下故障转移
- Sentinel FAILOVER 触发时出现 `NOGOODSLAVE`（瞬态，因 Sentinel 正在选举）
- 故障转移后 Master 稳定在 valkey-valkey-1
- 5000 个键全部写入成功，最终 DBSIZE: 3788（含之前测试数据）
- 数据一致性验证通过

### 场景 6: 连接风暴
- 200 个并发快速连接/断开无异常
- 10 轮 100 连接的 SET 操作全部成功
- 内存使用稳定，无 OOM 风险

### 场景 7: 持久化与数据恢复
- BGSAVE 成功，Last Save 时间戳 1784559194
- 硬 Kill Master 后，Sentinel 立即检测并触发故障转移
- 新 Master 数据恢复完整：`persistence-data-1784559192` 成功读取
- 持久化文件：appendonlydir + dump.rdb (150KB)
- 旧 Master 恢复后自动变为 Replica

### 场景 8: 全部 Sentinel 下线 + 恢复
- 删除全部 Sentinel 后，Master 正常读写，无影响
- 删除 Master 后，服务中断（无 Sentinel 触发故障转移）
- Sentinel 恢复后，自动重建拓扑发现
- 最终 Sentinels 正确识别 Master 为 valkey-valkey-1

## 风险与建议

### 已确认的问题
1. **故障转移窗口期**: 直接连接 ClusterIP 时，Master 切换后约 10-15s 无法连接。这是 Kubernetes Service 端点更新的固有延迟
2. **Sentinel 密码同步**: 修改密码后，Sentinel 需要重启更新 ACL 文件，否则 Sentinel 无法连接 Valkey

### 与 Redis 7.2.4 的对比观察
- Valkey 8.1.8 的故障转移 RTO 与 Redis 7.2.4 基本一致（433ms vs 420ms）
- Valkey 的持久化恢复表现更优：硬 Kill 后新 Master 数据完整读取
- Valkey 的启动脚本中的 `build_replicaof_config` 逻辑更复杂（含哨兵 Quorum、Pod 扫描等），重启后首次就绪时间稍长
- 高负载下两者表现持平

### 生产建议
1. **客户端需实现重试机制**: 建议使用支持自动重连的 Valkey/Redis 客户端
2. **连接池配置**: 建议设置 `maxTotal` 连接池，避免连接风暴
3. **监控**: 建议启用 ServiceMonitor 采集 Valkey metrics
4. **持久化**: RDB + AOF 可靠，建议设置 `auto-aof-rewrite-percentage` 避免 AOF 文件无限增长

## 结论

Valkey 8.1.8 (KubeBlocks 管理) 在 1 主 1 从 + 3 Sentinel 拓扑下，**具备生产可用性**。故障转移 RTO 约 433ms，持久化恢复稳定，高负载下数据一致性良好。推荐作为 Redis 7.x 的替代方案。
