# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

Flux Platform is a reusable Flux CD infrastructure template providing modular Kubernetes platform components. It is consumed by cluster instance repos (like `flux-cluster-template`) via Flux `GitRepository` + `Kustomization` resources. Configuration is injected at deploy time through a `platform-vars` ConfigMap and `platform-secrets` Secret using Flux's `postBuild.substituteFrom`.

## Common Commands

```bash
# Lint all YAML files (pre-commit hooks: trailing whitespace, EOF fixer, YAML syntax, yamllint)
pre-commit run --all-files

# Validate Kubernetes manifests against schemas
find infrastructure -name '*.yaml' -type f | xargs kubeconform -ignore-missing-schemas

# Validate a single module
kubectl kustomize infrastructure/core/ | kubeconform -ignore-missing-schemas
```

### Local E2E Testing (requires KinD, Flux CLI)

```bash
kind create cluster --config tests/e2e/kind-config.yaml
flux install
kubectl apply -f tests/e2e/test-vars.yaml
kubectl apply -f tests/e2e/test-secrets.yaml
flux create source git flux-platform --url=https://github.com/afloren-dev/flux-platform --branch=main
flux create kustomization platform-core --source=flux-platform --path=./infrastructure/core --prune=true
```

### Flux CLI

```bash
# Check status of all Flux resources
flux get all --all-namespaces

# Reconcile a specific kustomization
flux reconcile kustomization <name> --with-source

# Suspend/resume reconciliation
flux suspend kustomization <name>
flux resume kustomization <name>
```

### Debugging

```bash
# Check Flux logs
kubectl -n flux-system logs deploy/source-controller
kubectl -n flux-system logs deploy/kustomize-controller
kubectl -n flux-system logs deploy/helm-controller

# Get all pods across namespaces
kubectl get pods --all-namespaces

# Inspect a failing HelmRelease
flux get helmreleases --all-namespaces
kubectl describe helmrelease <name> -n <namespace>
```

### Accessing CI Debug Artifacts

When an E2E run fails, structured debug artifacts are uploaded automatically. Artifacts are retained for 7 days.

**Quick triage — view job summary inline (no download):**
```bash
gh run list --workflow=e2e.yaml --status=failure --limit=5
gh run view <run-id>   # shows Flux kustomizations, helmreleases, and pod status
```

**Full investigation — download all structured logs:**
```bash
gh run download <run-id> --dir /tmp/flux-run-<run-id>
```

Artifact directory layout:
```
flux-debug-<run-id>/
  flux/
    kustomizations.txt   # flux get kustomizations --all-namespaces
    helmreleases.txt     # flux get helmreleases --all-namespaces
    sources.txt          # flux get sources all --all-namespaces
    pods.txt             # kubectl get pods --all-namespaces
    events.txt           # kubectl get events (sorted by time)
    kustomize-controller.txt  # kustomize-controller logs
    helm-controller.txt       # helm-controller logs
  cluster-dump/
    <namespace>/
      <pod-name>/
        <container>.log  # per-container logs via kubectl cluster-info dump
      events.json
      pods.json
  kind-logs/
    kind-control-plane/
      journal.log        # kubelet / containerd logs
      containers/        # per-container logs from node perspective
```

## CI Pipeline

GitHub Actions workflow (`.github/workflows/e2e.yaml`) runs on push/PR to `main`:
1. **validate** job: yamllint + kubeconform on all manifests
2. **kubernetes** job: spins up KinD cluster, installs Flux, deploys `core` and `mesh` modules, verifies reconciliation. On failure, collects debug artifacts (Flux state, cluster-info dump, KinD node logs).

## Architecture

Each module under `infrastructure/` is self-contained with a `kustomization.yaml`, `namespace.yaml`, and component manifests. Modules use `${VAR_NAME}` placeholders that get substituted by Flux at reconciliation time.

**Required modules:** `core` (metrics-server), `mesh` (Istio: base, istiod, gateway, mesh config, ingress class)

**Optional modules:** `auth`, `certs`, `monitoring`, `tracing`, `autoscaling`, `dashboard`

Module dependency order is enforced by consumers via `dependsOn` in their Kustomization specs (e.g., mesh depends on core, auth depends on mesh+certs).

### Variable Substitution

All manifests use `${VAR_NAME}` placeholders substituted by Flux at reconciliation time.
In the E2E workflow, substitution is configured via `postBuild.substituteFrom` in the
Kustomization CRD manifests applied by `tests/e2e/deploy.sh`. When adding new modules,
add a Kustomization manifest to this script — do NOT add inline `flux create kustomization`
commands to the workflow (the CLI does not support `substituteFrom`).

## YAML Style Rules

Configured in `.yamllint.yaml`:
- 2-space indentation, sequences indented
- Max line length: 120 (warning only)
- No document-start markers required
- Truthy rule disabled
- 1+ space before inline comments

## Versioning

Uses git tags (e.g., `v1.0.0`). Cluster instances pin to specific tags in their `platform-source.yaml`.
