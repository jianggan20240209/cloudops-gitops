#!/usr/bin/env bash
# One-time cluster prep before re-running Jenkins Kaniko pipelines (build #37+).
# Run on harbor-server (or any host with kubectl + git + proxy).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RBAC="${ROOT}/dev/platform/jenkins/rbac/jenkins-kaniko-agent.yaml"
KUBECTL_IMAGE="${KUBECTL_IMAGE:-kubectl:1.30.4}"

if [[ -z "${HTTP_PROXY:-${http_proxy:-}}" && -f /etc/profile.d/proxy.sh ]]; then
  # shellcheck source=/dev/null
  source /etc/profile.d/proxy.sh
fi

echo "== sync cloudops-gitops =="
git -C "${ROOT}" fetch origin main
git -C "${ROOT}" checkout main
git -C "${ROOT}" pull --ff-only origin main

if [[ ! -f "${RBAC}" ]]; then
  echo "ERROR: missing ${RBAC} after git pull. Check remote cloudops-gitops main." >&2
  exit 1
fi

echo
echo "== apply Jenkins Kaniko RBAC =="
kubectl apply -f "${RBAC}"
kubectl -n devops get serviceaccount jenkins-kaniko-agent

echo
echo "== mirror kubectl sidecar image to Harbor (ONLY_IMAGES) =="
if ! command -v skopeo >/dev/null 2>&1; then
  echo "Installing skopeo (recommended over docker pull via proxy)..."
  apt-get update -qq && apt-get install -y skopeo
fi
ONLY_IMAGES="${KUBECTL_IMAGE}" PULL_TOOL=skopeo bash "${ROOT}/scripts/mirror-harbor-base-images.sh"

echo
echo "PASS: RBAC applied and ${KUBECTL_IMAGE} mirrored."
echo "Re-run Jenkins job test-cloudops-cicd-kaniko."
