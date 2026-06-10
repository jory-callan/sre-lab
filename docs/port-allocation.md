# CZW-SRE 集群端口分配规范

> 本文档记录 k3s 集群的 NodePort 端口规划、域名映射和服务清单。
> 新增服务时按此规范分配端口，保持文档同步更新。

## 端口区间

| 区间 | 分类 | 最大数量 | 说明 |
|------|------|----------|------|
| **30101–30199** | 监控 (Monitoring) | 99 | Prometheus 全家桶及日志存储 |
| **30201–30299** | 基础设施 (Infrastructure) | 99 | 数据库、中间件、SRE 工具 |
| **30301–30399** | 应用 (Applications) | 99 | 业务服务、演示应用 |

NodePort 有效范围由 Kubernetes 限制为 `30000–32767`（默认值），
如需扩容可在 `kube-apiserver` 启动参数中调整 `--service-node-port-range`。

## 当前端口分配

### 监控 — 301xx

| 域名 | 端口 | 服务名 | 命名空间 | 协议 | 说明 |
|------|------|--------|----------|------|------|
| `grafana.czw-sre.internal` | **30101** | `kube-prometheus-stack-grafana` | monitoring | HTTP | 监控面板 |
| `prometheus.czw-sre.internal` | **30102** | `prometheus-external` | monitoring | HTTP | 指标存储 |
| `alertmanager.czw-sre.internal` | **30103** | `alertmanager-external` | monitoring | HTTP | 告警管理 |
| `victorialogs.czw-sre.internal` | **30104** | `victoria-logs-external` | monitoring | HTTP | 日志存储 |

### 基础设施 — 302xx

| 域名 | 端口 | 服务名 | 命名空间 | 协议 | 说明 |
|------|------|--------|----------|------|------|
| `kite.czw-sre.internal` | **30201** | `kite` | kite | HTTP | SRE 工具 |
| `redis.czw-sre.internal` | **30202** | `redis-standalone` | redis-deployment | TCP (Redis) | 缓存 (Deployment) |
| `redis-sentinel.czw-sre.internal` | **30203** | `redis-sentinel-external` | redis | TCP (Redis) | 缓存哨兵 |
| `mysql.czw-sre.internal` | **30204** | `mysql` | mysql | TCP (MySQL) | 数据库 |
| `pg.czw-sre.internal` | **30205** | `pg-standalone-external` | pg | TCP (PostgreSQL) | 数据库 |

### 应用 — 303xx

| 域名 | 端口 | 服务名 | 命名空间 | 协议 | 说明 |
|------|------|--------|----------|------|------|
| `demo.czw-sre.internal` | **30301** | `demo-go-tiny-nodeport` | default | HTTP | 演示应用 |

## 本机 hosts 配置

在 macOS `/etc/hosts` 中添加：

```
192.168.5.100  grafana.czw-sre.internal
192.168.5.100  prometheus.czw-sre.internal
192.168.5.100  alertmanager.czw-sre.internal
192.168.5.100  victorialogs.czw-sre.internal
192.168.5.100  kite.czw-sre.internal
192.168.5.100  redis.czw-sre.internal
192.168.5.100  redis-sentinel.czw-sre.internal
192.168.5.100  mysql.czw-sre.internal
192.168.5.100  pg.czw-sre.internal
192.168.5.100  demo.czw-sre.internal
```

> 集群节点 IP：`192.168.5.100`（k3s-server-3），也可使用 `192.168.5.101` 或 `192.168.5.249`。

## 服务接入方式

### 集群外（本机 / 局域网）

```
协议   地址                                   说明
───    ────                                   ────
HTTP   http://grafana.czw-sre.internal:30101   监控面板（用户 admin 密码 admin123）
HTTP   http://prometheus.czw-sre.internal:30102
HTTP   http://alertmanager.czw-sre.internal:30103
HTTP   http://victorialogs.czw-sre.internal:30104
HTTP   http://kite.czw-sre.internal:30201
TCP    redis-cli -h redis.czw-sre.internal -p 30202 -a '<password>'
TCP    redis-cli -h redis-sentinel.czw-sre.internal -p 30203
TCP    mysql -h mysql.czw-sre.internal -P 30204 -u root -p
TCP    psql -h pg.czw-sre.internal -p 30205 -U postgres
HTTP   http://demo.czw-sre.internal:30301
```

### 集群内（Pod 相互调用）

| 服务 | 地址 |
|------|------|
| Grafana | `kube-prometheus-stack-grafana.monitoring.svc.cluster.local` |
| Prometheus | `kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090` |
| Alertmanager | `kube-prometheus-stack-alertmanager.monitoring.svc.cluster.local:9093` |
| VictoriaLogs | `victoria-logs.monitoring.svc.cluster.local:9428` |
| Kite | `kite.kite.svc.cluster.local:8080` |
| Redis | `redis-standalone.redis-deployment.svc.cluster.local:6379` |
| MySQL | `mysql.mysql.svc.cluster.local:3306` |
| PG | `pg-standalone-external.pg.svc.cluster.local:5432` |

## 新增服务规范

1. 按分类选择下一个可用端口（302xx → 30206、303xx → 30302…）
2. 在本文档表中添加一行
3. 在本机 hosts 中添加域名
4. 在对应服务目录的 `manifests/service.yaml` 中指定 `nodePort`
5. 确保端口不与其他服务冲突

## 历史变更

| 日期 | 变更内容 |
|------|---------|
| 2026-06-10 | 初始规范制定。统一分配到 301xx / 302xx / 303xx 区间。 |