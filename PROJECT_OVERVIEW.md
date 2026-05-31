# CZW SRE - Kubernetes 项目总览

## 📂 当前项目结构

```
czw-sre/
├── docker-compose/              # 保留：Docker Compose 项目（开发/参考）
│   ├── nginx/
│   ├── php82/
│   ├── postgresql15/
│   ├── redis/
│   └── ...
│
├── kubernetes/                  # ⭐ 新：Kubernetes 部署（核心）
│   ├── platforms/               # 平台特定配置
│   │   └── k3s/                 # 你现有的 k3s 部署工具（已迁移）
│   │       ├── install-k3s.sh
│   │       ├── config.yaml
│   │       ├── examples/
│   │       └── ...
│   │
│   ├── apps/                    # ⭐ 平台无关的应用定义
│   │   ├── catalog/             # 应用商店
│   │   │   └── kite/            # 你现有的 kite 应用（已迁移）
│   │   └── templates/           # 应用模板
│   │       └── helm-chart/
│   │
│   ├── infrastructure/          # 基础设施组件（待添加）
│   │   ├── ingress/
│   │   ├── monitoring/
│   │   └── logging/
│   │
│   ├── environments/            # 环境配置（待添加）
│   │   ├── development/
│   │   ├── staging/
│   │   └── production/
│   │
│   └── docs/                    # 文档
│       ├── structure.md         # 结构说明
│       ├── migration-guide.md   # 迁移指南
│       └── platform-switching.md
│
├── script/                      # 保留：原有脚本
├── systemctl/                   # 保留：原有 systemd 服务
└── docs/                        # 项目文档
```

---

## 🎯 设计优势

### 1. ✅ 易于迁移到其他 k8s 平台

```
想迁移到阿里云 ACK？
1. 在 kubernetes/platforms/ 下添加 ack/ 目录
2. 用 ACK 工具创建集群
3. 直接部署 apps/catalog/ 下的应用（无需修改！）
```

### 2. ✅ 快速部署应用

```bash
cd kubernetes/apps/catalog/nginx
./install.sh  # 完事！
```

### 3. ✅ 向后兼容

保留原有的 `docker-compose/` 目录，可继续使用。

---

## 🚀 下一步建议

### 短期（1-2周）
- [ ] 完善 `apps/templates/helm-chart/`，添加完整模板
- [ ] 将 `docker-compose/nginx/` 迁移到 `apps/catalog/nginx/`
- [ ] 将 `docker-compose/postgresql15/` 迁移到 `apps/catalog/postgresql/`

### 中期（1-2月）
- [ ] 添加 `infrastructure/` 组件（ingress-nginx, cert-manager...）
- [ ] 添加 `environments/` 配置
- [ ] 建立 GitOps 流程（ArgoCD）

### 长期
- [ ] 添加更多平台支持（eks, ack, tke...）
- [ ] 建立 CI/CD 流水线
- [ ] 完善监控告警体系

---

## 📚 相关文档

- [Kubernetes 结构说明](./kubernetes/docs/structure.md)
- [迁移指南](./kubernetes/docs/migration-guide.md)
- [平台切换指南](./kubernetes/docs/platform-switching.md)
- [k3s 文档](./kubernetes/platforms/README.md)
