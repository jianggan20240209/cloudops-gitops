#!/usr/bin/env bash
# Diagnose and fix conflicting dockerd HTTP proxy drop-ins on harbor-server.
# Optional: prefer IPv4 over IPv6 for registry pulls (dockerd ignores shell proxy on AAAA).
set -euo pipefail

DROPIN_DIR="/etc/systemd/system/docker.service.d"
OLD_DROPIN="${DROPIN_DIR}/proxy.conf"
NEW_DROPIN="${DROPIN_DIR}/http-proxy.conf"
GAI_CONF="/etc/gai.conf"
GAI_PRECEDENCE='precedence ::ffff:0:0/96  100'
FIX_IPV6="${FIX_IPV6:-0}" # 1 = apply gai.conf IPv4-preferred fix after proxy check

usage() {
  cat <<'EOF'
Usage: sudo bash fix-harbor-server-docker-proxy.sh [--ipv6]

  (default)  Remove legacy proxy.conf if it conflicts with http-proxy.conf
  --ipv6     Also set /etc/gai.conf to prefer IPv4 (fixes docker pull AAAA timeout)
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

fix_ipv6_gai() {
  echo "== IPv6 / gai.conf =="
  if [[ -f "${GAI_CONF}" ]] && grep -qF "${GAI_PRECEDENCE}" "${GAI_CONF}"; then
    echo "OK: ${GAI_CONF} already prefers IPv4 (${GAI_PRECEDENCE})"
    return 0
  fi
  local bak="${GAI_CONF}.bak.$(date +%Y%m%d%H%M%S)"
  if [[ -f "${GAI_CONF}" ]]; then
    cp -a "${GAI_CONF}" "${bak}"
    echo "Backed up ${GAI_CONF} -> ${bak}"
  fi
  {
    echo "# Added by fix-harbor-server-docker-proxy.sh — prefer IPv4 for docker.io AAAA"
    echo "${GAI_PRECEDENCE}"
  } >> "${GAI_CONF}"
  echo "Appended to ${GAI_CONF}: ${GAI_PRECEDENCE}"
  echo "Restart docker to pick up address selection: systemctl restart docker"
  echo
  echo "Alternatives if pull still times out on IPv6:"
  echo "  sysctl: echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6 (and default)"
  echo "  skopeo: source /etc/profile.d/proxy.sh && bash scripts/mirror-harbor-base-images.sh"
}

echo "== dockerd Environment =="
systemctl show docker --property=Environment
echo

echo "== drop-in files =="
ls -la "${DROPIN_DIR}/" 2>/dev/null || echo "(no drop-in dir)"
echo

for f in "${DROPIN_DIR}"/*; do
  [[ -f "${f}" ]] || continue
  echo "--- ${f} ---"
  cat "${f}"
  echo
done

echo "== /etc/docker/daemon.json proxies =="
if [[ -f /etc/docker/daemon.json ]]; then
  if grep -q '"proxies"' /etc/docker/daemon.json 2>/dev/null; then
    grep -A6 '"proxies"' /etc/docker/daemon.json || true
  else
    echo "(no proxies section)"
  fi
else
  echo "(missing)"
fi
echo

if [[ -f "${OLD_DROPIN}" && -f "${NEW_DROPIN}" ]]; then
  echo "WARN: both proxy.conf and http-proxy.conf exist."
  echo "      systemd merges drop-ins; proxy.conf often overrides http-proxy.conf."
  bak="${OLD_DROPIN}.bak.$(date +%Y%m%d%H%M%S)"
  mv "${OLD_DROPIN}" "${bak}"
  echo "Moved ${OLD_DROPIN} -> ${bak}"
  systemctl daemon-reload
  systemctl restart docker
  echo
  echo "== dockerd Environment after fix =="
  systemctl show docker --property=Environment
  echo
  echo "PASS: removed conflicting ${OLD_DROPIN}. Verify: docker pull golang:1.23-alpine"
elif [[ -f "${OLD_DROPIN}" ]]; then
  echo "WARN: only legacy ${OLD_DROPIN} found. Update or replace it with ${NEW_DROPIN}."
  exit 1
elif [[ -f "${NEW_DROPIN}" ]]; then
  echo "OK: only ${NEW_DROPIN} present."
else
  echo "WARN: no docker proxy drop-in found. Create ${NEW_DROPIN} from scripts/harbor-server-docker-http-proxy.conf.example"
  exit 1
fi

if [[ "${FIX_IPV6}" == "1" ]]; then
  echo
  fix_ipv6_gai
else
  echo
  echo "Tip: docker pull may still fail on IPv6 AAAA (dial tcp [2a03:...]:443 i/o timeout)."
  echo "     Re-run with --ipv6, or use skopeo via scripts/mirror-harbor-base-images.sh"
fi
