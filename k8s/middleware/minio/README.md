# MinIO — 对象存储

S3 兼容对象存储，基于 MinIO Operator 部署。版本锁定策略，不再主动升级。

## 版本锁定

| 组件 | 版本 | 锁定原因 |
|------|------|---------|
| MinIO Operator | v5.0.18 | v6.x 废弃 Console CRD，v5.x 最后一个版本 |
| MinIO 镜像 | RELEASE.2025-04-22T22-12-26Z | 最后一个完整 Web Console |

> **策略**：不再主动升级 Operator 或 MinIO 镜像版本，除非有严重安全漏洞需要修补。

## 结构

```
minio/
├── operator/                        ← Operator Helm chart (v5.0.18)
│   ├── operator-5.0.18.tgz
│   ├── install.sh                   ← 三模式
│   ├── values.yaml
│   └── README.md
├── common/
│   └── monitor/
│       └── servicemonitor.yaml
├── test-default/                    ← Tenant 实例
│   ├── deploy-tenant.yaml           ← Tenant CR
│   ├── secret-*.yaml                ← 凭证
│   ├── service-ingress-*.yaml       ← Ingress
│   ├── install.sh                   ← 三模式
│   ├── 部署.md
│   ├── 交付.md
│   └── README.md
├── AK.md                            ← 访问密钥管理
└── DELIVERY.md                      ← 交付详情
```

## 部署

```bash
# 1. 先部署 Operator
bash operator/install.sh install

# 2. 再部署 Tenant
bash test-default/install.sh install

# 或一键部署（test-default/install.sh 会自动检查 operator）
bash test-default/install.sh install
```

## 访问

| 位置 | 服务 | 地址 |
|------|------|------|
| 集群外部 | S3 API | https://minio-api.czw-sre.internal |
| 集群外部 | Console | https://minio.czw-sre.internal |
| 集群内部 | S3 API | http://minio.minio.svc:80 |
| 集群内部 | Console | http://minio-console.minio.svc:9090 |

## 凭证

| 账号 | 密码 | 角色 |
|------|------|------|
| minioadmin | minioadmin | root |

详情见 [AK.md](AK.md)。
