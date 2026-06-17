# K8s Deployments

Production-ready Kubernetes configurations for infrastructure and applications.

## Layout

```
k8s/
├── monitoring/             Observability stack
│   ├── helm-values.yaml    kube-prometheus-stack values
│   ├── dashboards/         Custom Grafana dashboards
│   └── exporters/          FluentBit, node-exporter configs
│
├── ingress/
│   ├── nginx/              ingress-nginx v1.12.0
│   └── metallb/            MetalLB v0.14.8
│
├── storage/
│   └── nfs/                NFS subdir external provisioner
│
├── databases/
│   ├── mysql/              MySQL 8.4 — Percona Operator
│   ├── postgresql/         PostgreSQL 17 — CloudNative PG
│   └── redis/              Redis 7 — 3 deployment modes
│
├── temporal/               Temporal workflow engine
│
└── apps/
    ├── kite/               K8s dashboard
    └── kdebug/             K8s debug pod
```

## Component Template

Each component follows this pattern:

```
component/
├── README.md               Architecture, commands, version
├── manifests/              Raw YAML (simple services)
├── helm/                   Custom Helm chart (self-managed services)
└── operator/               Operator CRs (stateful services)
```

## Version Management

Every README documents exact versions — images, Helm charts, operators. This ensures fully reproducible deployments.
