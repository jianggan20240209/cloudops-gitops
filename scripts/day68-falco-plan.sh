#!/usr/bin/env bash
# Day 68 — print Falco install plan (does not install unless CONFIRM=1)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VALUES="$ROOT/dev/platform/security/falco/values-lab.yaml"
cat <<EOF
# Falco install plan (Day 68)
# 1) Mirror falco images to Harbor if needed
# 2) helm repo add falcosecurity https://falcosecurity.github.io/charts
# 3) helm upgrade --install falco falcosecurity/falco \\
#      -n falco --create-namespace -f $VALUES
# 4) kubectl -n falco logs -l app.kubernetes.io/name=falco --tail=50
EOF
if [[ "${CONFIRM:-}" == "1" ]]; then
  helm repo add falcosecurity https://falcosecurity.github.io/charts || true
  helm repo update
  helm upgrade --install falco falcosecurity/falco -n falco --create-namespace -f "$VALUES"
else
  echo "Set CONFIRM=1 to actually install."
fi
