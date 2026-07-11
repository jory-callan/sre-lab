# MinIO AK 管理

MinIO 兼容 AWS S3 的访问控制模型：**Access Key (AK) = 用户名，Secret Key (SK) = 密码**。

## 当前预置账号

| AK | SK | 策略 | 权限范围 | 适用场景 |
|----|----|------|---------|---------|
| `minioadmin` | `minioadmin` | 内置 root | 全部操作（管理+数据） | 初始化、Console 登录、运维 |
| `svc-poweruser` | 见 Secret | `readwrite` | 所有 bucket 读写 | 通用服务账号（备份、迁移） |
| `svc-private` | 见 Secret | `private-rw` | 仅 `private` bucket 读写 | 仅需访问特定 bucket 的服务 |

> **生产环境必须修改** root 密码：更新 `secret.yaml` 中 `MINIO_ROOT_PASSWORD`。

## 三种创建方式

### 方式 1：Tenant CRD（声明式，推荐）

编辑 `tenant.yaml` 的 `spec.users` 列表：

```yaml
spec:
  users:
    - name: svc-myapp
```

创建对应 Secret：

```yaml
# secret-myapp.yaml
apiVersion: v1
kind: Secret
metadata:
  name: svc-myapp
  namespace: minio
type: Opaque
stringData:
  CONSOLE_ACCESS_KEY: svc-myapp
  CONSOLE_SECRET_KEY: <随机密码>
```

```bash
# 生成随机密码
openssl rand -base64 12

# 应用
kubectl apply -f secret-myapp.yaml
kubectl apply -f tenant.yaml
```

**注意**：Operator 创建的用户默认绑定 `consoleAdmin` 策略（管理员权限），创建后需要手动调整为所需策略（见下文"策略绑定"）。

### 方式 2：mc CLI（快速验证）

```bash
# 先设置 root 别名
kubectl -n minio exec deploy/minio-pool-0-0 -c minio -- mc alias set local http://localhost:9000 minioadmin minioadmin

# 创建用户
kubectl -n minio exec deploy/minio-pool-0-0 -c minio -- mc admin user add local <ak> <sk>

# 绑定策略
kubectl -n minio exec deploy/minio-pool-0-0 -c minio -- mc admin policy attach local <policy-name> --user=<ak>
```

### 方式 3：Console UI

访问 `https://minio.czw-sre.internal` → **Identity → Users → Create User**。

## 策略管理

### 内置策略

| 策略 | 权限 |
|------|------|
| `consoleAdmin` | 全部操作（管理员） |
| `readwrite` | 所有 bucket 读写 |
| `readonly` | 所有 bucket 只读 |
| `writeonly` | 所有 bucket 只写 |
| `diagnostics` | 诊断信息 |

### 自定义策略

创建 bucket 级别权限的 JSON 策略文件：

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": ["arn:aws:s3:::my-bucket"]
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": ["arn:aws:s3:::my-bucket/*"]
    }
  ]
}
```

```bash
# 创建策略
kubectl -n minio exec deploy/minio-pool-0-0 -c minio -- mc admin policy create local <policy-name> /tmp/policy.json

# 绑定到用户
kubectl -n minio exec deploy/minio-pool-0-0 -c minio -- mc admin policy attach local <policy-name> --user=<ak>

# 查看用户策略
kubectl -n minio exec deploy/minio-pool-0-0 -c minio -- mc admin user info local <ak>
```

### 解绑策略

```bash
kubectl -n minio exec deploy/minio-pool-0-0 -c minio -- mc admin policy detach local <policy-name> --user=<ak>
```

### 常用 Action

| Action | 说明 |
|--------|------|
| `s3:GetObject` | 读取文件 |
| `s3:PutObject` | 上传/写入文件 |
| `s3:DeleteObject` | 删除文件 |
| `s3:ListBucket` | 列出文件列表 |
| `s3:GetBucketPolicy` | 查看 bucket 策略 |

## 完整示例：新增一个仅 public bucket 只读的账号

```yaml
# secret-svc-public-reader.yaml
apiVersion: v1
kind: Secret
metadata:
  name: svc-public-reader
  namespace: minio
type: Opaque
stringData:
  CONSOLE_ACCESS_KEY: svc-public-reader
  CONSOLE_SECRET_KEY: <随机密码>
```

```bash
kubectl apply -f secret-svc-public-reader.yaml

# tenant.yaml 添加 users: - name: svc-public-reader
kubectl apply -f tenant.yaml

# 等 Pod 就绪后调整策略
POD=$(kubectl -n minio get pod -l app=minio -o name | head -1)

# 创建自定义策略
kubectl -n minio exec "$POD" -c minio -- sh -c 'cat > /tmp/public-read.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket", "s3:GetObject"],
      "Resource": ["arn:aws:s3:::public", "arn:aws:s3:::public/*"]
    }
  ]
}
EOF'
kubectl -n minio exec "$POD" -c minio -- mc admin policy create local public-read /tmp/public-read.json
kubectl -n minio exec "$POD" -c minio -- mc admin policy detach local consoleAdmin --user=svc-public-reader
kubectl -n minio exec "$POD" -c minio -- mc admin policy attach local public-read --user=svc-public-reader
```

## 验证权限

```bash
POD=$(kubectl -n minio get pod -l app=minio -o name | head -1)

# 设置别名
kubectl -n minio exec "$POD" -c minio -- mc alias set test http://localhost:9000 <ak> <sk>

# 测试写入（应被拒绝）
kubectl -n minio exec "$POD" -c minio -- sh -c 'echo "test" | mc pipe test/public/test.txt'

# 测试读取（应成功）
kubectl -n minio exec "$POD" -c minio -- mc cat test/public/test.txt
```

## 删除用户

```bash
# 从 tenant.yaml 移除 users 条目
kubectl apply -f tenant.yaml  # 只移除不会触发删除

# 手动删除
kubectl -n minio exec deploy/minio-pool-0-0 -c minio -- mc admin user remove local <ak>
kubectl delete secret <secret-name> -n minio
```
