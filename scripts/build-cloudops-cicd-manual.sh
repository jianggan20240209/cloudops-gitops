#!/usr/bin/env bash
# Manual fallback when Jenkins cannot fetch cloudops-platform from GitHub.
set -euo pipefail

IMAGE="${IMAGE:-harbor-server.jianggan.cn/cloudops/cloudops-cicd}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%s)}"
IMAGE_TAG="${IMAGE_TAG:-main-${BUILD_NUMBER}}"
ARGOCD_APP="${ARGOCD_APP:-cloudops-cicd-dev}"
PLATFORM_DIR="${PLATFORM_DIR:-$HOME/tools/cloudops-platform}"
PLATFORM_REPO="${PLATFORM_REPO:-https://github.com/jianggan20240209/cloudops-platform.git}"

echo "== clone or update cloudops-platform =="
if [[ -d "${PLATFORM_DIR}/.git" ]]; then
  git -C "${PLATFORM_DIR}" fetch origin main
  git -C "${PLATFORM_DIR}" checkout main
  git -C "${PLATFORM_DIR}" pull --ff-only origin main
else
  mkdir -p "$(dirname "${PLATFORM_DIR}")"
  git clone "${PLATFORM_REPO}" "${PLATFORM_DIR}"
fi

GIT_COMMIT_SHORT="$(git -C "${PLATFORM_DIR}" rev-parse --short=12 HEAD)"
BUILD_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo "commit=${GIT_COMMIT_SHORT} tag=${IMAGE_TAG} build_time=${BUILD_TIME}"

echo
echo "== docker build and push =="
docker build \
  -t "${IMAGE}:${IMAGE_TAG}" \
  --build-arg VERSION="${IMAGE_TAG}" \
  --build-arg COMMIT="${GIT_COMMIT_SHORT}" \
  --build-arg BUILD_TIME="${BUILD_TIME}" \
  "${PLATFORM_DIR}/services/cloudops-cicd"

docker push "${IMAGE}:${IMAGE_TAG}"

echo
echo "== sync Argo CD application =="
kubectl -n argocd annotate application "${ARGOCD_APP}" \
  argocd.argoproj.io/refresh=hard --overwrite
kubectl -n argocd patch application "${ARGOCD_APP}" --type merge \
  -p "{\"spec\":{\"source\":{\"helm\":{\"parameters\":[{\"name\":\"app.imageTag\",\"value\":\"${IMAGE_TAG}\",\"forceString\":true}]}}}}"
kubectl -n argocd patch application "${ARGOCD_APP}" --type merge \
  -p '{"operation":{"sync":{"revision":"main","prune":true}}}'

echo
echo "== wait for deployment =="
for _ in $(seq 1 36); do
  SYNC="$(kubectl -n argocd get application "${ARGOCD_APP}" -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"
  HEALTH="$(kubectl -n argocd get application "${ARGOCD_APP}" -o jsonpath='{.status.health.status}' 2>/dev/null || true)"
  DEPLOY_IMAGE="$(kubectl -n cloudops-dev get deploy cloudops-cicd -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)"
  echo "sync=${SYNC:-unknown} health=${HEALTH:-unknown} image=${DEPLOY_IMAGE:-unknown}"
  if [[ "${SYNC}" == "Synced" && "${HEALTH}" == "Healthy" && "${DEPLOY_IMAGE}" == *":${IMAGE_TAG}" ]]; then
    echo "PASS: cloudops-cicd deployed as ${IMAGE}:${IMAGE_TAG}"
    exit 0
  fi
  sleep 10
done

echo "WARN: timed out waiting for ${ARGOCD_APP} to become Synced/Healthy with ${IMAGE_TAG}"
kubectl -n argocd get application "${ARGOCD_APP}" || true
kubectl -n cloudops-dev get deploy cloudops-cicd -o wide || true
exit 1
