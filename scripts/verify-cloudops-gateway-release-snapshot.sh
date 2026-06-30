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

ensure_argocd_synced() {
  local app="${1:-cloudops-gateway-rollout-dev}"
  local sync
  sync=$(kubectl -n argocd get application "$app" -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
  if [[ "$sync" == "Synced" ]]; then
    pass "Argo CD Application ${app} is Synced."
    return 0
  fi
  echo "Argo CD sync status is ${sync}; refreshing..."
  kubectl -n argocd annotate application "$app" argocd.argoproj.io/refresh=hard --overwrite
  kubectl -n argocd patch application "$app" --type merge \
    -p '{"operation":{"sync":{"revision":"main","prune":true}}}' >/dev/null
  sleep 10
  sync=$(kubectl -n argocd get application "$app" -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
  if [[ "$sync" == "Synced" ]]; then
    pass "Argo CD Application ${app} is Synced after refresh."
  else
    warn "Argo CD sync is still ${sync}; snapshot status may be failed."
  fi
}

fetch_observability() {
  local attempt body
  for attempt in 1 2 3; do
    body=$(curl -k -s "${BASE}/observability" || true)
    if [[ -n "$body" ]] && echo "$body" | grep -q 'canary_stage'; then
      echo "$body"
      return 0
    fi
    sleep 5
  done
  echo "$body"
  return 1
}

post_snapshot() {
  local code body
  body=$(curl -k -s -w '\n%{http_code}' -X POST "${BASE}/records/snapshot")
  code=$(echo "$body" | tail -n1)
  body=$(echo "$body" | sed '$d')
  echo "$body"
  [[ "$code" == "201" || "$code" == "200" ]]
}

echo "== ensure Argo CD synced =="
ensure_argocd_synced "cloudops-gateway-rollout-dev"

echo
echo "== warm ingress traffic =="
warm_traffic
pass "Ingress traffic generated."

echo
echo "== observability (pre-snapshot) =="
OBS=""
if OBS=$(fetch_observability); then
  echo "$OBS" | head -c 2000
  echo
else
  echo "${OBS:-<empty>}"
  echo
fi
if echo "$OBS" | grep -q 'request_rate_rps'; then
  pass "Observability reports istio request_rate_rps."
elif echo "$OBS" | grep -q 'matched_selector'; then
  pass "Observability reports matched_selector."
elif echo "$OBS" | grep -q 'canary_stage'; then
  echo "INFO: Pre-snapshot observability has canary_stage only (istio metrics may need more traffic)."
else
  echo "INFO: Observability empty before snapshot (will verify snapshot record below)."
fi

echo
echo "== POST records/snapshot =="
SNAP=""
if SNAP=$(post_snapshot); then
  echo "$SNAP" | head -c 2000
  echo
else
  echo "$SNAP"
  warn "POST /records/snapshot failed (check cloudops-cicd logs and Argo CD sync status)."
fi
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
echo "records/latest returns the Jenkins base record, not necessarily the newest snapshot."
LATEST=$(curl -k -fsS "${BASE}/records/latest" || echo '{}')
if echo "$LATEST" | grep -q 'observability'; then
  pass "Base release record also exposes verification.observability."
fi

echo
if [[ "$FAIL" -ne 0 ]]; then
  echo "Snapshot verification finished with warnings."
  exit 1
fi
echo "Snapshot verification complete."
