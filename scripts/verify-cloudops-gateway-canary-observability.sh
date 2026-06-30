#!/usr/bin/env bash
# Trigger a new Rollout revision and capture observability + snapshot during canary stages.
set -euo pipefail

NAME="${1:-cloudops-gateway-rollout}"
NS="${2:-cloudops-dev}"
BASE="https://cloudops.jianggan.cn/api/v1/cicd/apps/${NAME}"
FAIL=0
MAX_WAIT="${MAX_WAIT:-600}"

warn() { echo "WARN: $*"; FAIL=1; }
pass() { echo "PASS: $*"; }

warm_traffic() {
  for _ in $(seq 1 20); do
    curl -k -s "https://api.cloudops.jianggan.cn/readyz" >/dev/null || true
  done
  sleep 10
}

fetch_observability() {
  curl -k -s "${BASE}/observability" 2>/dev/null || echo '{}'
}

observability_stage() {
  local obs
  obs=$(fetch_observability)
  echo "$obs" | grep -o '"stage":"[^"]*"' | head -n1 | cut -d'"' -f4 || echo "unknown"
}

canary_weight() {
  kubectl -n "$NS" get virtualservice "$NAME" -o jsonpath='{.spec.http[0].route[1].weight}' 2>/dev/null || echo "0"
}

stable_weight() {
  kubectl -n "$NS" get virtualservice "$NAME" -o jsonpath='{.spec.http[0].route[0].weight}' 2>/dev/null || echo "100"
}

rollout_phase() {
  kubectl -n "$NS" get rollout "$NAME" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown"
}

trigger_new_revision() {
  local ts
  ts=$(date -u +%s)
  # Rollout CRD accepts merge/json patch only (not strategic-merge-patch).
  kubectl -n "$NS" patch rollout "$NAME" --type=merge -p "{
    \"spec\": {
      \"template\": {
        \"metadata\": {
          \"annotations\": {
            \"cloudops-gitops/verify-rollout\": \"${ts}\"
          }
        }
      }
    }
  }"
}

wait_rollout_healthy() {
  local start now phase
  start=$(date +%s)
  while true; do
    phase=$(rollout_phase)
    if [[ "$phase" == "Healthy" ]]; then
      return 0
    fi
    now=$(date +%s)
    if (( now - start > MAX_WAIT )); then
      return 1
    fi
    echo "  rollout phase=${phase}"
    sleep 10
  done
}

save_stage_snapshot() {
  local label="$1"
  warm_traffic
  local obs stage cw sw
  obs=$(fetch_observability)
  stage=$(echo "$obs" | grep -o '"stage":"[^"]*"' | head -n1 | cut -d'"' -f4 || echo "unknown")
  cw=$(canary_weight)
  sw=$(stable_weight)
  echo "== ${label}: observability_stage=${stage} vs_weights=${sw}/${cw} =="
  echo "$obs" | head -c 1500
  echo
  local snap record_id code
  snap=$(curl -k -s -w '\n%{http_code}' -X POST "${BASE}/records/snapshot")
  code=$(echo "$snap" | tail -n1)
  snap=$(echo "$snap" | sed '$d')
  record_id=$(echo "$snap" | grep -o '"id":"[^"]*"' | head -n1 | cut -d'"' -f4 || true)
  echo "$snap" | head -c 1200
  echo
  if [[ "$code" == "201" || "$code" == "200" ]] && [[ -n "$record_id" ]]; then
    pass "${label}: snapshot ${record_id}"
  else
    warn "${label}: snapshot POST returned HTTP ${code}"
  fi
  if echo "$obs" | grep -qE 'request_rate_rps|matched_selector'; then
    pass "${label}: observability has istio metrics."
  else
    warn "${label}: observability missing istio metrics."
  fi
  if echo "$obs" | grep -q 'by_destination'; then
    pass "${label}: by_destination present."
  fi
}

command -v kubectl >/dev/null 2>&1 || { echo "ERROR: kubectl required."; exit 1; }

echo "== pre-check rollout =="
kubectl -n "$NS" get rollout "$NAME" -o wide
echo "current observability stage: $(observability_stage)"
echo "current VS weights stable/canary: $(stable_weight)/$(canary_weight)"

echo
echo "== trigger new revision (pod template annotation) =="
trigger_new_revision
pass "New Rollout revision triggered (not restartAt — that skips canary steps)."

echo
echo "== wait for canary stage (max ${MAX_WAIT}s) =="
CANARY_SEEN=0
START=$(date +%s)
while true; do
  NOW=$(date +%s)
  if (( NOW - START > MAX_WAIT )); then
    warn "Timed out waiting for canary stage."
    break
  fi
  STAGE=$(observability_stage)
  CW=$(canary_weight)
  SW=$(stable_weight)
  echo "  stage=${STAGE} vs=${SW}/${CW} rollout=$(rollout_phase)"
  if [[ "$CW" == "25" || "$CW" == "50" ]] || [[ "$STAGE" == canary_* ]]; then
    CANARY_SEEN=1
    save_stage_snapshot "canary-vs${CW:-${STAGE}}"
    pass "Captured snapshot during canary (weight=${CW}, stage=${STAGE})."
    break
  fi
  sleep 10
done

if [[ "$CANARY_SEEN" -eq 0 ]]; then
  warn "No canary stage observed. Confirm Rollout steps and VirtualService route weights."
fi

echo
echo "== wait for rollout completion =="
if wait_rollout_healthy; then
  pass "Rollout phase is Healthy."
else
  warn "Rollout did not reach Healthy within timeout."
fi

echo
save_stage_snapshot "post-rollout-stable"
FINAL_STAGE=$(observability_stage)
FINAL_CW=$(canary_weight)
if [[ "$FINAL_STAGE" == "stable" && "$FINAL_CW" == "0" ]]; then
  pass "Rollout returned to stable stage."
else
  warn "Final stage=${FINAL_STAGE} canary_weight=${FINAL_CW} (expected stable/0)."
fi

echo
if [[ "$FAIL" -ne 0 ]]; then
  echo "Canary observability verification finished with warnings."
  exit 1
fi
echo "Canary observability verification complete."
