#!/usr/bin/env bash
# Diagnose and fix dockerd/containerd HTTP proxy on harbor-server.
# Optional --ipv6: prefer IPv4 in gai.conf (registry-1.docker.io AAAA timeout).
set -euo pipefail

DOCKER_DROPIN_DIR="/etc/systemd/system/docker.service.d"
CONTAINERD_DROPIN_DIR="/etc/systemd/system/containerd.service.d"
OLD_DROPIN="${DOCKER_DROPIN_DIR}/proxy.conf"
DOCKER_PROXY="${DOCKER_DROPIN_DIR}/http-proxy.conf"
CONTAINERD_PROXY="${CONTAINERD_DROPIN_DIR}/http-proxy.conf"
GAI_CONF="/etc/gai.conf"
GAI_PRECEDENCE='precedence ::ffff:0:0/96  100'
FIX_IPV6="${FIX_IPV6:-0}"

usage() {
  cat <<'EOF'
Usage: sudo bash fix-harbor-server-docker-proxy.sh [--ipv6]

  (default)  Remove legacy proxy.conf, sync proxy to containerd, restart services
  --ipv6     Also append gai.conf IPv4 preference (fixes docker pull AAAA timeout)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ipv6) FIX_IPV6=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

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

fix_ipv6_gai() {
  echo "== IPv6 / gai.conf =="
  if [[ -f "${GAI_CONF}" ]] && grep -qF "${GAI_PRECEDENCE}" "${GAI_CONF}"; then
    echo "OK: ${GAI_CONF} already prefers IPv4"
    return 0
  fi
  local bak="${GAI_CONF}.bak.$(date +%Y%m%d%H%M%S)"
  if [[ -f "${GAI_CONF}" ]]; then
    cp -a "${GAI_CONF}" "${bak}"
    echo "Backed up ${GAI_CONF} -> ${bak}"
  fi
  {
    echo "# Added by fix-harbor-server-docker-proxy.sh - prefer IPv4 for docker.io AAAA"
    echo "${GAI_PRECEDENCE}"
  } >> "${GAI_CONF}"
  echo "Appended to ${GAI_CONF}: ${GAI_PRECEDENCE}"
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

if [[ "${FIX_IPV6}" == "1" ]]; then
  fix_ipv6_gai
fi

systemctl daemon-reload
systemctl restart containerd
systemctl restart docker

echo
show_unit_env docker
show_unit_env containerd

echo "PASS: proxy applied to docker + containerd."
if [[ "${FIX_IPV6}" != "1" ]]; then
  echo "If docker pull still dials IPv6 and times out, re-run: sudo bash $0 --ipv6"
fi
echo "Test: docker pull docker.io/library/golang:1.23-alpine"
echo "Fallback: source /etc/profile.d/proxy.sh && bash scripts/mirror-harbor-base-images.sh"
