# Grafana Dashboard 导入

## Dashboard 文件位置

v0.9.0 提供的 Grafana dashboard 位于原项目：

```bash
# 从 git checkout v0.9.0 中获取
cat /Users/czw/code/redis-operator/dashboards/redis-operator-cluster.json
```

## 导入步骤

1. 打开 Grafana → **+** → **Import**
2. Upload JSON file 或粘贴 JSON 内容
3. 选择数据源（Prometheus）
4. 点击 **Import**

## 面板说明

该 dashboard 包含以下面板：

- **Redis 集群概览** — 节点数、角色分布
- **内存使用** — OOM 风险监控
- **连接数** — 负载情况
- **Key 统计** — QPS、Key 数量、过期 Key
- **复制延迟** — 主从同步延迟
- **命中率** — Cache hit/miss 比率
