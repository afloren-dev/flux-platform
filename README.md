# Flux Platform

Reusable Flux CD infrastructure template with autoscaling and telemetry.

## Overview

This repository contains modular, reusable infrastructure components for Kubernetes clusters managed by Flux CD. It provides a complete platform stack including service mesh, authentication, certificates, monitoring, tracing, autoscaling, and dashboard capabilities.

## Modules

| Module | Path | Description | Required? |
|--------|------|-------------|-----------|
| core | `infrastructure/core/` | Metrics server and core utilities | Yes |
| mesh | `infrastructure/mesh/` | Istio service mesh | Yes |
| auth | `infrastructure/auth/` | Dex + OAuth2 Proxy authentication | Optional |
| certs | `infrastructure/certs/` | cert-manager for TLS certificates | Optional |
| monitoring | `infrastructure/monitoring/` | Prometheus + Grafana + Loki | Optional |
| tracing | `infrastructure/tracing/` | Jaeger distributed tracing | Optional |
| autoscaling | `infrastructure/autoscaling/` | Knative Serving + Eventing | Optional |
| dashboard | `infrastructure/dashboard/` | Kubernetes Dashboard | Optional |

## Usage

This template is designed to be consumed by cluster instance repositories via Flux `GitRepository` + `Kustomization` resources.

See [flux-cluster-template](https://github.com/afloren-dev/flux-cluster-template) for a scaffold to create your own cluster instance.

## Variables

The following variables must be provided via a `ConfigMap` named `platform-vars` in the `flux-system` namespace:

- `DOMAIN` - Your domain name (e.g., `example.com`)
- `ACME_EMAIL` - Email for Let's Encrypt certificates
- `GCP_PROJECT` - GCP project for DNS01 solver (optional, leave empty if not using)
- `TRACING_SAMPLE_RATE` - Jaeger sampling rate (0-100)
- `PROMETHEUS_RETENTION` - Prometheus data retention period
- `LOKI_RETENTION` - Loki log retention period
- `INGRESS_TYPE` - Ingress type (`NodePort` or `LoadBalancer`)
- `GRAFANA_ADMIN_PASSWORD` - Grafana admin password

The following secrets must be provided via a `Secret` named `platform-secrets` in the `flux-system` namespace:

- `OAUTH_CLIENT_ID` - OAuth client ID for Google authentication
- `OAUTH_CLIENT_SECRET` - OAuth client secret
- `OAUTH_COOKIE_SECRET` - Cookie secret for OAuth2 Proxy (16+ bytes)

## Testing

Run pre-commit hooks:
```bash
pre-commit run --all-files
```

Run E2E tests locally with KinD:
```bash
kind create cluster --config tests/e2e/kind-config.yaml
kubectl apply -f tests/e2e/test-vars.yaml
kubectl apply -f tests/e2e/test-secrets.yaml
flux install
flux create source git flux-platform --url=https://github.com/afloren-dev/flux-platform --branch=main
flux create kustomization platform-core --source=flux-platform --path=./infrastructure/core --prune=true
```

## Versioning

This repository uses git tags for versioning (e.g., `v1.0.0`, `v1.1.0`). Cluster instances should pin to a specific tag to ensure stability.

## License

MIT
