#!/usr/bin/env bash
# Trigger a Rollout restart and capture observability + snapshot during canary stages.
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

observability_stage() {
  curl -k -fsS "${BASE}/observability" 2>/dev/null | \
    grep -o '"stage":"[^"]*"' | head -n1 | cut -d'"' -f4 || echo "unknown"
}

rollout_phase() {
  kubectl -n "$NS" get rollout "$NAME" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown"
}

restart_rollout() {
  kubectl -n "$NS" patch rollout "$NAME" --type merge \
    -p "{\"spec\":{\"restartAt\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}}"
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
  local obs stage
  obs=$(curl -k -fsS "${BASE}/observability")
  stage=$(echo "$obs" | grep -o '"stage":"[^"]*"' | head -n1 | cut -d'"' -f4 || echo "unknown")
  echo "== ${label}: stage=${stage} =="
  echo "$obs" | head -c 1500
  echo
  local snap record_id
  snap=$(curl -k -fsS -X POST "${BASE}/records/snapshot")
  record_id=$(echo "$snap" | grep -o '"id":"[^"]*"' | head -n1 | cut -d'"' -f4 || true)
  echo "$snap" | head -c 1200
  echo
  if [[ -n "$record_id" ]]; then
    pass "${label}: snapshot ${record_id}"
  fi
  if echo "$obs" | grep -qE 'request_rate_rps|matched_selector'; then
    pass "${label}: observability has istio metrics (stage=${stage})."
  else
    warn "${label}: observability missing istio metrics (stage=${stage})."
  fi
  if echo "$obs" | grep -q 'by_destination'; then
    pass "${label}: by_destination present."
  fi
}

command -v kubectl >/dev/null 2>&1 || { echo "ERROR: kubectl required."; exit 1; }

echo "== pre-check rollout =="
kubectl -n "$NS" get rollout "$NAME" -o wide
INITIAL_STAGE=$(observability_stage)
echo "current observability stage: ${INITIAL_STAGE}"

echo
echo "== restart rollout to enter canary =="
restart_rollout
pass "Rollout restart issued (kubectl patch spec.restartAt)."

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
  echo "  stage=${STAGE} rollout=$(rollout_phase)"
  case "$STAGE" in
    canary_25|canary_50|canary_*)
      CANARY_SEEN=1
      save_stage_snapshot "canary-${STAGE}"
      pass "Captured snapshot during ${STAGE}."
      break
      ;;
    stable)
      sleep 10
      ;;
    progressing|Progressing|*)
      sleep 10
      ;;
  esac
done

if [[ "$CANARY_SEEN" -eq 0 ]]; then
  warn "No canary stage observed; check Rollout steps and VirtualService weights."
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
if [[ "$FINAL_STAGE" == "stable" ]]; then
  pass "Rollout returned to stable stage."
else
  warn "Final stage is ${FINAL_STAGE} (expected stable)."
fi

echo
if [[ "$FAIL" -ne 0 ]]; then
  echo "Canary observability verification finished with warnings."
  exit 1
fi
echo "Canary observability verification complete."
