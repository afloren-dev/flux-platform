#!/usr/bin/env bash
set -euo pipefail

# Apply Kustomization CRD manifests with postBuild.substituteFrom
# (flux create kustomization does not support --substitute-from)
#
# Only required modules (core + mesh) are tested here. Optional modules
# (certs, monitoring, tracing, auth, autoscaling, dashboard) depend on
# CRDs installed by their own HelmReleases or external Helm repos that
# may be unavailable in a KinD test environment.

kubectl apply -f - <<'EOF'
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: platform-core
  namespace: flux-system
spec:
  interval: 10m
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-platform
  path: ./infrastructure/core
  timeout: 5m
  postBuild:
    substituteFrom:
      - kind: ConfigMap
        name: platform-vars
      - kind: Secret
        name: platform-secrets
  wait: true
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: platform-mesh-controllers
  namespace: flux-system
spec:
  dependsOn:
    - name: platform-core
  interval: 10m
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-platform
  path: ./infrastructure/mesh/controllers
  postBuild:
    substituteFrom:
      - kind: ConfigMap
        name: platform-vars
      - kind: Secret
        name: platform-secrets
  wait: true
  timeout: 5m
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: platform-mesh-configs
  namespace: flux-system
spec:
  dependsOn:
    - name: platform-mesh-controllers
  interval: 10m
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-platform
  path: ./infrastructure/mesh/configs
  postBuild:
    substituteFrom:
      - kind: ConfigMap
        name: platform-vars
      - kind: Secret
        name: platform-secrets
  wait: true
  timeout: 5m
EOF

echo "Waiting for platform-core..."
kubectl -n flux-system wait kustomization/platform-core --for=condition=Ready --timeout=5m

echo "Waiting for platform-mesh-controllers..."
kubectl -n flux-system wait kustomization/platform-mesh-controllers --for=condition=Ready --timeout=5m

echo "Waiting for platform-mesh-configs..."
kubectl -n flux-system wait kustomization/platform-mesh-configs --for=condition=Ready --timeout=5m

# --- Verify resource readiness ---
echo ""
echo "==> Verifying HelmRelease status..."
flux get helmreleases --all-namespaces

echo ""
echo "==> Verifying pod readiness..."
kubectl wait pods --for=condition=Ready --all -n kube-system --timeout=3m
kubectl wait pods --for=condition=Ready --all -n istio-system --timeout=3m
kubectl wait pods --for=condition=Ready --all -n istio-ingress --timeout=3m

echo ""
echo "==> All pod statuses:"
kubectl get pods --all-namespaces

echo ""
echo "All required platform modules deployed and verified."
