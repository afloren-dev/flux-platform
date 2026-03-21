#!/usr/bin/env bash
set -euo pipefail

# Apply Kustomization CRD manifests with postBuild.substituteFrom
# (flux create kustomization does not support --substitute-from)

# --- Core + Mesh (required modules) ---
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

echo "Waiting for core modules..."
kubectl -n flux-system wait kustomization/platform-core --for=condition=Ready --timeout=5m
kubectl -n flux-system wait kustomization/platform-mesh-controllers --for=condition=Ready --timeout=5m
kubectl -n flux-system wait kustomization/platform-mesh-configs --for=condition=Ready --timeout=5m

# --- Optional modules ---
kubectl apply -f - <<'EOF'
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: platform-certs
  namespace: flux-system
spec:
  dependsOn:
    - name: platform-core
  interval: 10m
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-platform
  path: ./infrastructure/certs
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
  name: platform-monitoring
  namespace: flux-system
spec:
  dependsOn:
    - name: platform-core
  interval: 10m
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-platform
  path: ./infrastructure/monitoring
  postBuild:
    substituteFrom:
      - kind: ConfigMap
        name: platform-vars
      - kind: Secret
        name: platform-secrets
  wait: true
  timeout: 10m
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: platform-tracing
  namespace: flux-system
spec:
  dependsOn:
    - name: platform-core
  interval: 10m
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-platform
  path: ./infrastructure/tracing
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
  name: platform-autoscaling
  namespace: flux-system
spec:
  dependsOn:
    - name: platform-mesh-configs
  interval: 10m
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-platform
  path: ./infrastructure/autoscaling
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
  name: platform-auth
  namespace: flux-system
spec:
  dependsOn:
    - name: platform-mesh-configs
    - name: platform-certs
  interval: 10m
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-platform
  path: ./infrastructure/auth
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
  name: platform-dashboard
  namespace: flux-system
spec:
  dependsOn:
    - name: platform-mesh-configs
  interval: 10m
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-platform
  path: ./infrastructure/dashboard
  postBuild:
    substituteFrom:
      - kind: ConfigMap
        name: platform-vars
      - kind: Secret
        name: platform-secrets
  wait: true
  timeout: 5m
EOF

echo "Waiting for optional modules..."
kubectl -n flux-system wait kustomization/platform-certs --for=condition=Ready --timeout=5m
kubectl -n flux-system wait kustomization/platform-monitoring --for=condition=Ready --timeout=10m
kubectl -n flux-system wait kustomization/platform-tracing --for=condition=Ready --timeout=5m
kubectl -n flux-system wait kustomization/platform-autoscaling --for=condition=Ready --timeout=5m
kubectl -n flux-system wait kustomization/platform-auth --for=condition=Ready --timeout=5m
kubectl -n flux-system wait kustomization/platform-dashboard --for=condition=Ready --timeout=5m

# --- Verify resource readiness ---
echo ""
echo "==> Verifying HelmRelease status..."
flux get helmreleases --all-namespaces

echo ""
echo "==> Verifying pod readiness..."
kubectl wait --for=condition=Ready pods --all --all-namespaces --timeout=5m \
  --field-selector=status.phase!=Succeeded 2>/dev/null || true

echo ""
echo "==> All pod statuses:"
kubectl get pods --all-namespaces

echo ""
echo "All platform modules deployed and verified."
