#!/usr/bin/env bash
# Verify Istio circuit breaker DestinationRules synced via Helm trafficPolicy.
set -euo pipefail

NAME="${1:-cloudops-gateway-rollout}"
NS="${2:-cloudops-dev}"
BASE="https://cloudops.jianggan.cn/api/v1/cicd/apps/${NAME}"
FAIL=0

warn() { echo "WARN: $*"; FAIL=1; }
pass() { echo "PASS: $*"; }

echo "== DestinationRule resources =="
if kubectl -n "$NS" get destinationrule "${NAME}" "${NAME}-canary" >/dev/null 2>&1; then
  kubectl -n "$NS" get destinationrule "${NAME}" "${NAME}-canary"
  pass "DestinationRule stable + canary exist."
else
  warn "DestinationRule not found. Enable trafficPolicy.circuitBreaker in values/cloudops-gateway.yaml and sync Argo CD."
  kubectl -n "$NS" get destinationrule 2>/dev/null | grep "$NAME" || true
fi

echo
echo "== outlierDetection / connectionPool =="
for dr in "${NAME}" "${NAME}-canary"; do
  if kubectl -n "$NS" get destinationrule "$dr" >/dev/null 2>&1; then
    echo "-- ${dr}"
    kubectl -n "$NS" get destinationrule "$dr" -o yaml | \
      grep -E 'consecutive5xxErrors|maxConnections|http1MaxPendingRequests|baseEjectionTime' || true
  fi
done

if kubectl -n "$NS" get destinationrule "$NAME" -o yaml 2>/dev/null | grep -q 'consecutive5xxErrors'; then
  pass "Outlier detection configured on stable DestinationRule."
else
  warn "Outlier detection not found on stable DestinationRule."
fi

echo
echo "== cloudops-cicd /traffic destination_rules =="
TRAFFIC=$(curl -k -fsS "${BASE}/traffic" || true)
echo "$TRAFFIC" | head -c 2500
echo
if echo "$TRAFFIC" | grep -q 'destination_rules'; then
  pass "/traffic reports destination_rules."
elif echo "$TRAFFIC" | grep -q 'consecutive5xx'; then
  pass "/traffic includes circuit breaker settings."
else
  warn "/traffic has no destination_rules summary (DestinationRule may be missing)."
fi

echo
echo "== snapshot with traffic policy =="
curl -k -fsS -X POST "${BASE}/records/snapshot" | head -c 2000
echo
pass "Snapshot saved (check verification.traffic in records/latest)."

echo
if [[ "$FAIL" -ne 0 ]]; then
  echo "Circuit breaker verification finished with warnings."
  exit 1
fi
echo "Circuit breaker verification complete."
