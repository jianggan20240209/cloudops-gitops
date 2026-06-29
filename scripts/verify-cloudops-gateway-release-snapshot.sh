#!/usr/bin/env bash
# Verify Release Record snapshot includes verification.observability.
set -euo pipefail

NAME="${1:-cloudops-gateway-rollout}"
BASE="https://cloudops.jianggan.cn/api/v1/cicd/apps/${NAME}"
FAIL=0

warn() { echo "WARN: $*"; FAIL=1; }
pass() { echo "PASS: $*"; }

warm_traffic() {
  for _ in $(seq 1 30); do
    curl -k -s "https://api.cloudops.jianggan.cn/readyz" >/dev/null || true
  done
  sleep 15
}

echo "== warm ingress traffic =="
warm_traffic
pass "Ingress traffic generated."

echo
echo "== observability (pre-snapshot) =="
OBS=$(curl -k -fsS "${BASE}/observability")
echo "$OBS" | head -c 2000
echo
if echo "$OBS" | grep -q 'request_rate_rps'; then
  pass "Observability reports istio request_rate_rps."
elif echo "$OBS" | grep -q 'matched_selector'; then
  pass "Observability reports matched_selector."
else
  warn "Observability missing istio metrics before snapshot."
fi

echo
echo "== POST records/snapshot =="
SNAP=$(curl -k -fsS -X POST "${BASE}/records/snapshot")
echo "$SNAP" | head -c 2000
echo
RECORD_ID=$(echo "$SNAP" | grep -o '"id":"[^"]*"' | head -n1 | cut -d'"' -f4 || true)
if [[ -n "${RECORD_ID}" ]]; then
  pass "Snapshot created: ${RECORD_ID}"
else
  warn "Snapshot response missing record id."
fi

echo
echo "== GET records/latest =="
LATEST=$(curl -k -fsS "${BASE}/records/latest")
echo "$LATEST" | head -c 3000
echo

if echo "$LATEST" | grep -q '"source":"snapshot"'; then
  pass "Latest record source is snapshot."
else
  warn "Latest record is not from snapshot."
fi

if echo "$LATEST" | grep -q 'observability'; then
  pass "Latest record includes verification.observability."
else
  warn "Latest record missing verification.observability."
fi

if echo "$LATEST" | grep -qE 'canary_stage|request_rate_rps|matched_selector'; then
  pass "Observability payload contains canary_stage or istio metrics."
else
  warn "Observability payload incomplete in latest record."
fi

echo
if [[ "$FAIL" -ne 0 ]]; then
  echo "Snapshot verification finished with warnings."
  exit 1
fi
echo "Snapshot verification complete."
