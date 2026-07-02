#!/usr/bin/env bash
# Diagnose and fix conflicting dockerd HTTP proxy drop-ins on harbor-server.
set -euo pipefail

DROPIN_DIR="/etc/systemd/system/docker.service.d"
OLD_DROPIN="${DROPIN_DIR}/proxy.conf"
NEW_DROPIN="${DROPIN_DIR}/http-proxy.conf"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root: sudo bash $0" >&2
  exit 1
fi

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
