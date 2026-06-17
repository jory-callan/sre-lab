# SRE Playbook

> Infrastructure-as-Code: from bare metal to Kubernetes.

[![CI](https://github.com/jory-callan/sre-playbook/actions/workflows/ci.yml/badge.svg)](https://github.com/jory-callan/sre-playbook/actions/workflows/ci.yml)

A collection of battle-tested infrastructure configurations and deployment patterns for SREs. This repository documents real-world practices across the full stack — provisioning, container orchestration, observability, and application delivery.

## Architecture

```
provisioning/     → OS init, networking, base setup
platform/         → Docker, k3s, kubectl/helm installation
compose/          → Local dev & CI with Docker Compose
k8s/              → Production-grade K8s deployments
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

> Built from real production experience. Inspired by [Astro AntfuStyle Theme](https://github.com/lin-stephanie/astro-antfustyle-theme) for documentation structure.
