#!/usr/bin/env bash
set -euo pipefail

FLUX_SOURCE="GitRepository/flux-platform"
SUBS="--substitute-from=ConfigMap/platform-vars --substitute-from=Secret/platform-secrets"

# Core module
flux create kustomization platform-core \
  --source=$FLUX_SOURCE \
  --path=./infrastructure/core \
  --prune=true --interval=10m \
  $SUBS --wait

# Mesh controllers (HelmReleases that install CRDs)
flux create kustomization platform-mesh-controllers \
  --source=$FLUX_SOURCE \
  --path=./infrastructure/mesh/controllers \
  --prune=true --interval=10m \
  $SUBS --wait --timeout=5m

# Mesh configs (CRD-dependent resources, must wait for controllers)
flux create kustomization platform-mesh-configs \
  --source=$FLUX_SOURCE \
  --path=./infrastructure/mesh/configs \
  --prune=true --interval=10m \
  --depends-on=platform-mesh-controllers \
  $SUBS --wait --timeout=5m
