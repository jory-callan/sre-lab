redis-operator/
├── Chart.yaml
├── values.yaml
├── crds/                    # CRD 定义（Helm 自动安装，永不更新）
│   ├── redis.yaml
│   └── redisclusters.yaml
└── templates/
    ├── _helpers.tpl
    ├── namespace.yaml
    ├── serviceaccount.yaml
    ├── clusterrole.yaml
    ├── clusterrolebinding.yaml
    ├── deployment.yaml
    ├── redis-standalone.yaml     # 条件创建（standalone.enabled）
    ├── redis-cluster.yaml        # 条件创建（cluster.enabled）
    └── servicemonitor.yaml       # 条件创建（serviceMonitor.enabled）
