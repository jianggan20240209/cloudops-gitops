#!/usr/bin/env bash
# Mirror Docker Hub base images into Harbor for Kaniko builds.
# Prefer skopeo/crane (honor HTTP_PROXY, bypass broken docker daemon registry-mirrors).
set -euo pipefail

HARBOR="${HARBOR:-harbor-server.jianggan.cn}"
PROJECT="${PROJECT:-base}"
PROXY="${HTTP_PROXY:-http://192.168.1.50:7890}"
DEST_CERT_DIR="${DEST_CERT_DIR:-/etc/docker/certs.d/${HARBOR}}"
AUTH_FILE="${AUTH_FILE:-${DOCKER_CONFIG:-$HOME/.docker}/config.json}"
PULL_TOOL="${PULL_TOOL:-auto}" # auto | skopeo | crane | docker

IMAGES=(
  "golang:1.23-alpine"
  "nginx:1.27-alpine"
)

export HTTP_PROXY="${PROXY}"
export HTTPS_PROXY="${PROXY}"
export http_proxy="${PROXY}"
export https_proxy="${PROXY}"
export NO_PROXY="${NO_PROXY:-localhost,127.0.0.1,::1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12,.jianggan.cn,${HARBOR}}"
export no_proxy="${NO_PROXY}"

hub_ref() {
  local name_tag="$1"
  local name="${name_tag%%:*}"
  local tag="${name_tag##*:}"
  printf 'docker.io/library/%s:%s' "${name}" "${tag}"
}

dest_ref() {
  local name_tag="$1"
  local name="${name_tag%%:*}"
  local tag="${name_tag##*:}"
  printf 'docker://%s/%s/%s:%s' "${HARBOR}" "${PROJECT}" "${name}" "${tag}"
}

skopeo_copy() {
  local src="$1"
  local dest="$2"
  local -a args=(
    copy
    --retry-times 5
    "docker://${src}"
    "${dest}"
  )
  if [[ -f "${AUTH_FILE}" ]]; then
    args+=(--src-authfile "${AUTH_FILE}" --dest-authfile "${AUTH_FILE}")
  fi
  if [[ -d "${DEST_CERT_DIR}" ]]; then
    args+=(--dest-cert-dir "${DEST_CERT_DIR}")
  fi
  skopeo "${args[@]}"
}

crane_copy() {
  local src="$1"
  local dest="$2"
  crane copy "${src}" "${dest/ docker:\/\//}"
}

docker_copy() {
  local name_tag="$1"
  local dest="$2"
  local harbor_image="${HARBOR}/${PROJECT}/${name_tag}"

  if grep -q 'registry-mirrors' /etc/docker/daemon.json 2>/dev/null; then
    echo "WARN: /etc/docker/daemon.json has registry-mirrors (e.g. daocloud)."
    echo "      docker pull may ignore HTTP_PROXY and fail TLS to the mirror."
    echo "      Install skopeo: apt install -y skopeo"
    echo "      Or remove registry-mirrors and configure docker daemon HTTP proxy."
  fi

  docker pull "${name_tag}"
  docker tag "${name_tag}" "${harbor_image}"
  docker push "${harbor_image}"
}

pick_tool() {
  case "${PULL_TOOL}" in
    skopeo) command -v skopeo ;;
    crane) command -v crane ;;
    docker) command -v docker ;;
    auto)
      if command -v skopeo >/dev/null 2>&1; then echo skopeo
      elif command -v crane >/dev/null 2>&1; then echo crane
      elif command -v docker >/dev/null 2>&1; then echo docker
      else return 1
      fi
      ;;
    *) echo "Unknown PULL_TOOL=${PULL_TOOL}" >&2; return 1 ;;
  esac
}

TOOL="$(pick_tool || true)"
if [[ -z "${TOOL}" ]]; then
  echo "ERROR: need skopeo, crane, or docker. Recommended: apt install -y skopeo" >&2
  exit 1
fi

echo "Harbor project: ${HARBOR}/${PROJECT}"
echo "Pull proxy: ${PROXY}"
echo "Copy tool: ${TOOL}"
echo "Ensure Harbor project '${PROJECT}' exists and docker/skopeo is logged in to ${HARBOR}."
echo

for name_tag in "${IMAGES[@]}"; do
  src="$(hub_ref "${name_tag}")"
  dest="$(dest_ref "${name_tag}")"
  echo "== ${src} -> ${dest} =="
  case "${TOOL}" in
    skopeo) skopeo_copy "${src}" "${dest}" ;;
    crane) crane_copy "${src}" "${dest#docker://}" ;;
    docker) docker_copy "${name_tag}" "${dest}" ;;
  esac
  echo
done

echo "PASS: base images mirrored to ${HARBOR}/${PROJECT}/"
