# SRE Playbook

> Infrastructure-as-Code: from bare metal to Kubernetes.

A collection of battle-tested infrastructure configurations and deployment patterns for SREs. This repository documents real-world practices across the full stack — provisioning, container orchestration, observability, and application delivery.

## Architecture

```
provisioning/     → OS init, networking, base setup
platform/         → Docker, k3s, kubectl/helm installation
docker-compose/   → Local dev & CI with Docker Compose
k8s/              → Production-grade K8s deployments
argocd/           → GitOps: ArgoCD Application configs (see README)
scripts/          → Utility tools
```

Each component follows the same layout:

```
component/
├── README.md       # Purpose, architecture, version matrix
├── manifests/      # kubectl apply -f ready YAMLs
├── helm/           # Custom Helm charts (optional)
└── operator/       # Operator CRs for stateful services (optional)
```

## Repository

- **Owner**: [Jory Callan](https://github.com/jory-callan)
- **License**: MIT
