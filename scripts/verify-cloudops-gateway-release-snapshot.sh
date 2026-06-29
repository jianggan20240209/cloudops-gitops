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

if [[ -n "${RECORD_ID}" ]]; then
  echo
  echo "== GET records/${RECORD_ID} =="
  RECORD=$(curl -k -fsS "${BASE}/records/${RECORD_ID}")
  echo "$RECORD" | head -c 3500
  echo

  if echo "$RECORD" | grep -q '"source":"snapshot"'; then
    pass "Snapshot record source is snapshot."
  else
    warn "Record ${RECORD_ID} is not marked source=snapshot."
  fi

  if echo "$RECORD" | grep -q 'observability'; then
    pass "Snapshot record includes verification.observability."
  else
    warn "Snapshot record missing verification.observability."
  fi

  if echo "$RECORD" | grep -qE 'canary_stage|request_rate_rps|matched_selector'; then
    pass "Snapshot observability contains canary_stage or istio metrics."
  else
    warn "Snapshot observability payload incomplete."
  fi
fi

echo
echo "== note on records/latest =="
echo "records/latest returns the Jenkins base record (source=jenkins/static), not the snapshot id."
LATEST=$(curl -k -fsS "${BASE}/records/latest")
if echo "$LATEST" | grep -q 'observability'; then
  pass "Base release record also exposes verification.observability."
else
  echo "Base record id: $(echo "$LATEST" | grep -o '"id":"[^"]*"' | head -n1 || true)"
fi

echo
if [[ "$FAIL" -ne 0 ]]; then
  echo "Snapshot verification finished with warnings."
  exit 1
fi
echo "Snapshot verification complete."
