# Redis Sentinel HA 验证

## 架构

```
                 ┌─────────────┐
                 │  Sentinel   │
                 │  仲裁层     │
                 │  3 节点     │
                 └──────┬──────┘
                        │ 监控 + 故障切换
    ┌───────────────────┼───────────────────┐
    │                   │                   │
┌───▼────────┐   ┌─────▼──────┐   ┌────────▼───┐
│  Redis     │   │  Redis     │   │  Redis     │
│  Master    │◄──│  Replica   │◄──│  Replica   │
│  读写      │   │  读        │   │  读        │
└─────┬──────┘   └─────┬──────┘   └──────┬─────┘
      │                │                 │
      └────────────────┴─────────────────┘
      9121 (redis-exporter) → ServiceMonitor → VMAgent
```

## 验证步骤

```bash
# 1. 部署
kubectl apply -k .

# 2. 等待所有 Pod 就绪
kubectl wait pod -l app.kubernetes.io/name=redis -n redis --for=condition=Ready --timeout=120s
kubectl wait pod -l app.kubernetes.io/name=redis-sentinel -n redis --for=condition=Ready --timeout=120s

# 3. 检查角色
for pod in redis-0 redis-1 redis-2; do echo "$pod: $(kubectl exec -n redis $pod -- redis-cli ROLE | head -1)"; done

# 4. 检查 Sentinel
kubectl exec -n redis redis-sentinel-0 -- redis-cli -p 26379 SENTINEL GET-MASTER-ADDR-BY-NAME redis

# 5. 运行混沌测试
bash chaos-test.sh all
```

## 测试场景

| 编号 | 场景 | 预期 |
|------|------|------|
| 1 | 删除 1 个 Slave | Pod 重建，自动加入复制 |
| 2 | 删除 Master | Sentinel 完成故障切换，新 master 上线 |
| 3 | 删除 1 个 Sentinel | 重建恢复，仲裁不受影响 |
| 5 | 删除 2 个 Sentinels | 仲裁丢失，不应发生切换 |
| 6 | 删除全部 Sentinels | 复制正常，但无自动切换 |
