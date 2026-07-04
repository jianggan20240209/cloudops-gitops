#!/usr/bin/env bash
# Mirror Docker Hub base images into Harbor for Kaniko builds.
# Prefer skopeo/crane (honor HTTP_PROXY, bypass dockerd registry-mirrors and IPv6 AAAA).
set -euo pipefail

HARBOR="${HARBOR:-harbor-server.jianggan.cn}"
# 镜像路径与 Docker Hub 一致，仅替换 registry 域名：
#   docker.io/library/busybox:1.36 -> harbor-server.jianggan.cn/library/busybox:1.36

if [[ -z "${HTTP_PROXY:-${http_proxy:-}}" && -f /etc/profile.d/proxy.sh ]]; then
  # shellcheck source=/dev/null
  source /etc/profile.d/proxy.sh
fi
PROXY="${HTTP_PROXY:-${http_proxy:-}}"
DEST_CERT_DIR="${DEST_CERT_DIR:-/etc/docker/certs.d/${HARBOR}}"
AUTH_FILE="${AUTH_FILE:-${DOCKER_CONFIG:-$HOME/.docker}/config.json}"
PULL_TOOL="${PULL_TOOL:-auto}" # auto | skopeo | crane | docker

IMAGES=(
  "golang:1.23-alpine"
  "nginx:1.27-alpine"
  "busybox:1.36"
)

export HTTP_PROXY="${PROXY}"
export HTTPS_PROXY="${PROXY}"
export http_proxy="${PROXY}"
export https_proxy="${PROXY}"
export NO_PROXY="${NO_PROXY:-localhost,127.0.0.1,::1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12,.jianggan.cn,${HARBOR},docker.m.daocloud.io,daocloud.io}"
export no_proxy="${NO_PROXY}"

# docker.io 经代理不稳定时，busybox 等基础镜像改从 DaoCloud 国内源拉取
src_ref() {
  local name_tag="$1"
  local name="${name_tag%%:*}"
  local tag="${name_tag##*:}"
  case "${name}" in
    busybox)
      printf 'docker.m.daocloud.io/library/%s:%s' "${name}" "${tag}"
      ;;
    *)
      printf 'docker.io/library/%s:%s' "${name}" "${tag}"
      ;;
  esac
}

dest_ref() {
  local name_tag="$1"
  local name="${name_tag%%:*}"
  local tag="${name_tag##*:}"
  printf 'docker://%s/library/%s:%s' "${HARBOR}" "${name}" "${tag}"
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
  local harbor_image="${HARBOR}/library/${name_tag}"

  if grep -q 'registry-mirrors' /etc/docker/daemon.json 2>/dev/null; then
    echo "WARN: /etc/docker/daemon.json has registry-mirrors (e.g. daocloud)."
    echo "      docker pull may ignore HTTP_PROXY and fail TLS to the mirror."
    echo "      Install skopeo: apt install -y skopeo"
    echo "      Or remove registry-mirrors and configure docker daemon HTTP proxy."
  fi
  echo "WARN: docker pull may dial registry-1.docker.io over IPv6 and timeout."
  echo "      Prefer: apt install -y skopeo && PULL_TOOL=skopeo bash $0"
  echo "      Or: sudo bash scripts/fix-harbor-server-docker-proxy.sh --ipv6"

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

if [[ -z "${PROXY}" ]]; then
  echo "ERROR: HTTP_PROXY not set. Run: source /etc/profile.d/proxy.sh" >&2
  echo "       (or install /etc/profile.d/proxy.sh from scripts/harbor-server-profile-proxy.sh.example)" >&2
  exit 1
fi

if [[ "${TOOL}" == "docker" ]]; then
  echo "WARN: using docker pull; skopeo avoids dockerd IPv6/registry-mirror issues." >&2
  echo "      Recommended: apt install -y skopeo" >&2
fi

echo "Harbor registry: ${HARBOR}/library/"
echo "Pull proxy: ${PROXY}"
echo "Copy tool: ${TOOL}"
echo "Ensure Harbor project 'library' exists and docker/skopeo is logged in to ${HARBOR}."
echo

for name_tag in "${IMAGES[@]}"; do
  src="$(src_ref "${name_tag}")"
  dest="$(dest_ref "${name_tag}")"
  echo "== ${src} -> ${dest} =="
  case "${TOOL}" in
    skopeo) skopeo_copy "${src}" "${dest}" ;;
    crane) crane_copy "${src}" "${dest#docker://}" ;;
    docker) docker_copy "${name_tag}" "${dest}" ;;
  esac
  echo
done

echo "PASS: base images mirrored to ${HARBOR}/library/"
