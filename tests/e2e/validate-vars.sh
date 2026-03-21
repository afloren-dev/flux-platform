#!/usr/bin/env bash
set -euo pipefail

# Validate that every ${VAR_NAME} used in infrastructure manifests
# is defined in the E2E test ConfigMap or Secret.

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
INFRA_DIR="$REPO_ROOT/infrastructure"
VARS_FILE="$REPO_ROOT/tests/e2e/test-vars.yaml"
SECRETS_FILE="$REPO_ROOT/tests/e2e/test-secrets.yaml"

# Extract all unique ${VAR_NAME} references from infrastructure manifests
# shellcheck disable=SC2016
used_vars=$(grep -roh '\${[A-Z_]\+}' "$INFRA_DIR" \
  | sed 's/\${\(.*\)}/\1/' \
  | sort -u)

# Extract variable names defined in test-vars.yaml and test-secrets.yaml
defined_vars=$(grep -hE '^\s+[A-Z_]+:' "$VARS_FILE" "$SECRETS_FILE" \
  | sed -E 's/^[[:space:]]*([A-Z_]+):.*/\1/' \
  | sort -u)

missing=0
for var in $used_vars; do
  if ! echo "$defined_vars" | grep -qx "$var"; then
    echo "ERROR: Variable \${$var} used in infrastructure/ but not defined in test configs"
    missing=1
  fi
done

if [ "$missing" -eq 1 ]; then
  echo ""
  echo "Add missing variables to tests/e2e/test-vars.yaml or tests/e2e/test-secrets.yaml"
  exit 1
fi

echo "All platform variables are covered in test configs."
