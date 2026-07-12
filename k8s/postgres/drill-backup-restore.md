# PostgreSQL 备份恢复演练

> 本文档模拟**误删数据 → 从 MinIO 备份恢复**的完整流程。
> 适用场景：开发环境验证备份是否可用、交接文档给值班人员、演练容灾 SOP。

---

## 环境确认

```bash
# 确认集群健康
kubectl get cluster -n postgres
kubectl get pods -n postgres
kubectl cnpg status pg-ha -n postgres
```

期望输出：

```
NAME    AGE   INSTANCES   READY   STATUS                    PRIMARY
pg-ha   1d    3           3       Cluster in healthy state   pg-ha-1

NAME        READY   STATUS    RESTARTS   AGE
pg-ha-1     1/1     Running   0          5h
pg-ha-2     1/1     Running   0          5h
pg-ha-3     1/1     Running   0          5h
```

---

## 第一步：写入测试数据

```bash
# 获取超级用户密码
PG_PASS=$(kubectl get secret pg-auth-secret -n postgres -o jsonpath='{.data.password}' | base64 -d)
echo "postgres password: $PG_PASS"

# 写入测试数据
kubectl exec -n postgres -it pg-ha-1 -- psql -U postgres -d postgres -c "
CREATE TABLE IF NOT EXISTS demo_data (
    id SERIAL PRIMARY KEY,
    value TEXT,
    created_at TIMESTAMP DEFAULT now()
);

INSERT INTO demo_data (value) VALUES
    ('备份前数据-A'),
    ('备份前数据-B'),
    ('备份前数据-C');

SELECT * FROM demo_data;
"
```

记录当前时间，后面 PITR（时间点恢复）要用：

```bash
# 记录"删表前"的时间
BEFORE_DELETE=$(date '+%Y-%m-%d %H:%M:%S')
echo "删表前时间: $BEFORE_DELETE"
```

---

## 第二步：触发全量备份

```bash
# 手动触发一次全量备份
kubectl cnpg backup pg-ha -n postgres

# 等待备份完成（约 1-2 分钟，取决于数据量）
watch -n 5 kubectl get backup -n postgres
```

期望输出：

```
NAME                    AGE     PHASE     CLUSTER   STARTED   COMPLETED   ...
pg-ha-manual-20260712   30s     running   pg-ha     ...       ...
```

等到 `PHASE` 变为 `completed`。

```bash
# 查看备份详情
kubectl get backup -n postgres

# 查看 MinIO 上的备份文件
kubectl -n minio exec deploy/minio-pool-0-0 -c minio -- mc ls --recursive local/postgres-backup/
```

你应该能看到类似 `base_20260712T140000/` 的目录，里面是 tar.gz 数据文件。

---

## 第三步：模拟误删数据

```bash
# 删除测试数据（模拟事故）
kubectl exec -n postgres -it pg-ha-1 -- psql -U postgres -d postgres -c "
DELETE FROM demo_data;
SELECT count(*) AS 剩余行数 FROM demo_data;
"
```

确认是 0 行。再写入一些"新数据"（模拟删数据后又继续写入了）：

```bash
kubectl exec -n postgres -it pg-ha-1 -- psql -U postgres -d postgres -c "
INSERT INTO demo_data (value) VALUES ('错误写入的数据');
SELECT * FROM demo_data;
"
```

---

## 第四步：从备份恢复

恢复方式有两种：

### 方式 A：恢复到最新备份（推荐，最快）

恢复 = 创建一个**新 Cluster**，从指定备份文件还原：

```bash
# 获取最近一次备份名称
BACKUP_NAME=$(kubectl get backup -n postgres -o jsonpath='{.items[-1].metadata.name}')
echo "使用备份: $BACKUP_NAME"
```

创建恢复 Cluster CR：

```bash
cat <<EOF | kubectl apply -f -
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: pg-ha-restored
  namespace: postgres
spec:
  instances: 3
  imageName: ghcr.io/cloudnative-pg/postgresql:17
  storage:
    size: 10Gi
    storageClass: local-path
  walStorage:
    size: 5Gi
    storageClass: local-path
  bootstrap:
    recovery:
      backup:
        name: ${BACKUP_NAME}
  backup:
    barmanObjectStore:
      destinationPath: s3://postgres-backup/
      endpointURL: http://minio.minio.svc:80
      s3Credentials:
        accessKeyId:
          name: pg-s3-creds
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: pg-s3-creds
          key: ACCESS_SECRET_KEY
EOF
```

等待恢复集群就绪（约 2-3 分钟）：

```bash
watch -n 10 kubectl get cluster -n postgres
```

当 `STATUS` 变为 `Cluster in healthy state` 时，验证数据：

```bash
kubectl exec -n postgres -it pg-ha-restored-1 -- psql -U postgres -d postgres -c "
SELECT * FROM demo_data;
"
```

期望输出——恢复出来的是**备份时的数据**，不含"错误写入的数据"：

```
 id |     value      |          created_at
----+----------------+-------------------------------
  1 | 备份前数据-A   | 2026-07-12 14:00:00.123456
  2 | 备份前数据-B   | 2026-07-12 14:00:00.234567
  3 | 备份前数据-C   | 2026-07-12 14:00:00.345678
```

✅ 恢复成功！

### 方式 B：时间点恢复（PITR，精确到秒）

如果你记得误删操作的精确时间，可以恢复到那个时间**之前**：

```bash
# 获取备份名称
BACKUP_NAME=$(kubectl get backup -n postgres -o jsonpath='{.items[-1].metadata.name}')

# PITR 恢复 — 恢复到删表前 1 分钟
cat <<EOF | kubectl apply -f -
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: pg-ha-pitr
  namespace: postgres
spec:
  instances: 3
  imageName: ghcr.io/cloudnative-pg/postgresql:17
  storage:
    size: 10Gi
    storageClass: local-path
  walStorage:
    size: 5Gi
    storageClass: local-path
  bootstrap:
    recovery:
      backup:
        name: ${BACKUP_NAME}
      recoveryTarget:
        targetTime: "${BEFORE_DELETE}"
  backup:
    barmanObjectStore:
      destinationPath: s3://postgres-backup/
      endpointURL: http://minio.minio.svc:80
      s3Credentials:
        accessKeyId:
          name: pg-s3-creds
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: pg-s3-creds
          key: ACCESS_SECRET_KEY
EOF
```

> **注意**：PITR 依赖 WAL 归档。如果在 `wal.maxAge: 7d` 范围内且有对应的 WAL 记录，就可以精确恢复到指定秒。如果 WAL 已被清理（超过 7 天），则只能恢复到最新全量备份的时间点。

---

## 第五步：切换流量到恢复集群

确认恢复数据正确后，切换应用连接：

```bash
# 1. 停掉原集群写入（可选，由业务决定）
# kubectl delete cluster pg-ha -n postgres

# 2. 切换 Service 指向恢复集群（或直接改应用配置）
# 推荐方案：更新应用配置中的 host 为 pg-ha-restored-rw.postgres.svc

# 3. 如果要沿用原 Service 名，可以用额外的 Service 重新指向
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: pg-ha-restored-external
  namespace: postgres
spec:
  type: NodePort
  ports:
    - port: 5432
      targetPort: 5432
      nodePort: 30007
  selector:
    cnpg.io/cluster: pg-ha-restored
    cnpg.io/podRole: instance
EOF
```

---

## 清理

```bash
# 演练完成后删除恢复集群
kubectl delete cluster pg-ha-restored -n postgres
kubectl delete cluster pg-ha-pitr -n postgres

# 验证 PVC 也清理了
kubectl get pvc -n postgres | grep restored
```

---

## 恢复速度参考

| 数据量 | 恢复方式 | 预估时间 |
|--------|---------|---------|
| 5Gi | 最新备份恢复 | 1-2 分钟 |
| 50Gi | 最新备份恢复 | 5-10 分钟 |
| 5Gi | PITR（额外回放 1h WAL） | 2-4 分钟 |
| 50Gi | PITR（额外回放 1h WAL） | 10-20 分钟 |

> 实际速度取决于：网络带宽（S3 下载）、CPU（解压 gzip）、WAL 回放量。

---

## 常见问题

| 问题 | 原因 | 解决 |
|------|------|------|
| `recovery cluster stuck` | 原集群还在写，WAL 冲突 | 确认原集群 `pg-ha` 没在写入 |
| `backup not found` | 备份名称写错 | `kubectl get backup -n postgres` 查看正确名称 |
| `S3 credentials error` | MinIO 不可达或凭证错 | `kubectl -n minio get pods` 检查 MinIO |
| PITR 恢复出来数据不对 | `targetTime` 在误删之前了吗？ | WAL 粒度到秒级，确认时间准确 |
