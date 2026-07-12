# redis-core 备份恢复

## 自动备份
每天 03:00 通过 CronJob 拉取 RDB 快照到 PVC，保留 7 天。

## 手动触发
```bash
kubectl create job --from=cronjob/redis-core-backup -n redis backup-$(date +%s)
```

## 恢复
```bash
# 1. 找到最近备份
kubectl get pods -n redis -l job-name=backup-xxx

# 2. 拷贝 RDB 到数据目录（需要临时 Pod 挂载两个 PVC）
# 3. 重启 StatefulSet 加载新 RDB
kubectl delete pod -n redis -l app.kubernetes.io/component=redis
```
