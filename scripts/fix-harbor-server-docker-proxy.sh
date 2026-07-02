#!/usr/bin/env bash
# Diagnose and fix dockerd/containerd HTTP proxy on harbor-server.
set -euo pipefail

DOCKER_DROPIN_DIR="/etc/systemd/system/docker.service.d"
CONTAINERD_DROPIN_DIR="/etc/systemd/system/containerd.service.d"
OLD_DROPIN="${DOCKER_DROPIN_DIR}/proxy.conf"
DOCKER_PROXY="${DOCKER_DROPIN_DIR}/http-proxy.conf"
CONTAINERD_PROXY="${CONTAINERD_DROPIN_DIR}/http-proxy.conf"
GAI_CONF="/etc/gai.conf"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root: sudo bash $0" >&2
  exit 1
fi

show_unit_env() {
  local unit="$1"
  echo "== ${unit} Environment =="
  systemctl show "${unit}" --property=Environment 2>/dev/null || echo "(unit not found)"
  echo
}

show_unit_env docker
show_unit_env containerd

echo "== docker drop-ins =="
ls -la "${DOCKER_DROPIN_DIR}/" 2>/dev/null || echo "(none)"
for f in "${DOCKER_DROPIN_DIR}"/*; do
  [[ -f "${f}" ]] || continue
  echo "--- ${f} ---"
  cat "${f}"
  echo
done

echo "== containerd drop-ins =="
ls -la "${CONTAINERD_DROPIN_DIR}/" 2>/dev/null || echo "(none)"
for f in "${CONTAINERD_DROPIN_DIR}"/*; do
  [[ -f "${f}" ]] || continue
  echo "--- ${f} ---"
  cat "${f}"
  echo
done

if [[ -f "${OLD_DROPIN}" ]]; then
  bak="${OLD_DROPIN}.bak.$(date +%Y%m%d%H%M%S)"
  mv "${OLD_DROPIN}" "${bak}"
  echo "Moved legacy ${OLD_DROPIN} -> ${bak}"
fi

if [[ ! -f "${DOCKER_PROXY}" ]]; then
  echo "ERROR: missing ${DOCKER_PROXY}" >&2
  echo "Create it from scripts/harbor-server-docker-http-proxy.conf.example" >&2
  exit 1
fi

mkdir -p "${CONTAINERD_DROPIN_DIR}"
if [[ ! -f "${CONTAINERD_PROXY}" ]]; then
  cp "${DOCKER_PROXY}" "${CONTAINERD_PROXY}"
  echo "Created ${CONTAINERD_PROXY} from docker http-proxy.conf"
elif ! cmp -s "${DOCKER_PROXY}" "${CONTAINERD_PROXY}"; then
  cp "${DOCKER_PROXY}" "${CONTAINERD_PROXY}"
  echo "Updated ${CONTAINERD_PROXY} to match docker http-proxy.conf"
else
  echo "OK: containerd proxy drop-in already matches docker"
fi

if ! grep -q '::ffff:0:0/96' "${GAI_CONF}" 2>/dev/null; then
  cat >>"${GAI_CONF}" <<'EOF'

# Prefer IPv4 over IPv6 (avoid docker pull dialing registry-1.docker.io via IPv6 timeout)
precedence ::ffff:0:0/96  100
EOF
  echo "Appended IPv4 preference to ${GAI_CONF}"
else
  echo "OK: ${GAI_CONF} already prefers IPv4"
fi

systemctl daemon-reload
systemctl restart containerd
systemctl restart docker

echo
show_unit_env docker
show_unit_env containerd

echo "PASS: proxy applied to docker + containerd. Test:"
echo "  docker pull docker.io/library/golang:1.23-alpine"
echo "If docker pull still fails, use skopeo (honors shell HTTP_PROXY):"
echo "  source /etc/profile.d/proxy.sh"
echo "  bash scripts/mirror-harbor-base-images.sh"
