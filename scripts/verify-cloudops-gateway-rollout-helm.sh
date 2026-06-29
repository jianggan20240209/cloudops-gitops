#!/usr/bin/env bash
# Verify cloudops-gateway-rollout Helm migration and trafficPolicy sync.
set -euo pipefail

APP="cloudops-gateway-rollout-dev"
NS="cloudops-dev"
NAME="cloudops-gateway-rollout"
EXPECTED_PATH="dev/backend/rollouts/chart"
FAIL=0

warn() { echo "WARN: $*"; FAIL=1; }
pass() { echo "PASS: $*"; }

echo "== Argo CD Application =="
kubectl -n argocd get application "$APP" \
  -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,REVISION:.status.sync.revision

SYNC=$(kubectl -n argocd get application "$APP" -o jsonpath='{.status.sync.status}')
HEALTH=$(kubectl -n argocd get application "$APP" -o jsonpath='{.status.health.status}')
SOURCE_PATH=$(kubectl -n argocd get application "$APP" -o jsonpath='{.spec.source.path}')
VALUE_FILES=$(kubectl -n argocd get application "$APP" -o jsonpath='{.spec.source.helm.valueFiles}')

echo
echo "== Helm source =="
echo "path: ${SOURCE_PATH}"
echo "valueFiles: ${VALUE_FILES:-<none>}"

if [[ "$SOURCE_PATH" != "$EXPECTED_PATH" ]]; then
  warn "Application path is still '$SOURCE_PATH'; expected '$EXPECTED_PATH'."
  echo "Fix:"
  echo "  kubectl apply -f dev/backend/argocd/application/cloudops-gateway-rollout-dev.yaml"
  echo "  kubectl -n argocd annotate application $APP argocd.argoproj.io/refresh=hard --overwrite"
  echo "  kubectl -n argocd patch application $APP --type merge -p '{\"operation\":{\"sync\":{\"revision\":\"main\",\"prune\":true}}}'"
else
  pass "Application uses Helm chart path."
fi

if [[ -z "$VALUE_FILES" ]]; then
  warn "Helm valueFiles is empty; expected values/cloudops-gateway.yaml"
elif [[ "$VALUE_FILES" != *"values/cloudops-gateway.yaml"* ]]; then
  warn "Helm valueFiles is '$VALUE_FILES'; expected values/cloudops-gateway.yaml inside chart path."
else
  pass "Helm valueFiles configured."
fi

if [[ "$SYNC" != "Synced" ]]; then
  warn "Application sync status is $SYNC (expected Synced)."
else
  pass "Application is Synced."
fi

if [[ "$HEALTH" != "Healthy" ]]; then
  warn "Application health is $HEALTH (expected Healthy)."
else
  pass "Application is Healthy."
fi

echo
echo "== Rollout / Istio resources =="
kubectl -n "$NS" get rollout,svc,gateway,virtualservice,destinationrule,servicemonitor -l "app.kubernetes.io/name=$NAME"

echo
echo "== VirtualService weights / timeout =="
VS_DUMP=$(kubectl -n "$NS" get virtualservice "$NAME" -o yaml)
echo "$VS_DUMP" | grep -E 'weight:|timeout:|attempts:|retryOn:' || true

if echo "$VS_DUMP" | grep -q 'timeout:'; then
  pass "VirtualService timeout/retry is enabled."
else
  warn "VirtualService has no timeout/retry yet. Sync Helm chart after applying updated Application."
fi

echo
echo "== API health =="
curl -k -fsS "https://api.cloudops.jianggan.cn/readyz"
echo
curl -k -fsS "https://api.cloudops.jianggan.cn/api/v1/version"
echo
pass "API endpoints respond."

echo
echo "== cloudops-cicd traffic =="
TRAFFIC=$(curl -k -fsS "https://cloudops.jianggan.cn/api/v1/cicd/apps/$NAME/traffic")
echo "$TRAFFIC" | head -c 2000
echo
if echo "$TRAFFIC" | grep -q 'timeout'; then
  pass "cloudops-cicd /traffic reports timeout/retry."
else
  warn "cloudops-cicd /traffic has no timeout/retry (expected until Helm sync completes)."
fi

echo
echo "== warm ingress traffic for istio metrics =="
for _ in $(seq 1 30); do
  curl -k -s "https://api.cloudops.jianggan.cn/readyz" >/dev/null || true
done
sleep 15
pass "Generated ingress traffic for Prometheus rate() window."

echo
echo "== cloudops-cicd observability =="
OBS_CODE=$(curl -k -s -o /tmp/cloudops-observability.json -w '%{http_code}' \
  "https://cloudops.jianggan.cn/api/v1/cicd/apps/$NAME/observability" || true)
if [[ "$OBS_CODE" == "200" ]]; then
  cat /tmp/cloudops-observability.json | head -c 2000
  echo
  if grep -q 'request_rate_rps' /tmp/cloudops-observability.json; then
    pass "cloudops-cicd /observability reports istio request_rate_rps."
  elif grep -q 'matched_selector' /tmp/cloudops-observability.json; then
    pass "cloudops-cicd /observability is available (matched_selector present)."
  elif grep -q '"stage":"stable"' /tmp/cloudops-observability.json; then
    warn "cloudops-cicd /observability returns canary_stage but no istio metrics yet. Run scripts/discover-istio-metrics.sh and confirm ingress gateway scrape."
  else
    warn "cloudops-cicd /observability has no istio request_rate_rps. Run scripts/discover-istio-metrics.sh in cluster."
  fi
else
  warn "cloudops-cicd /observability returned HTTP $OBS_CODE. Run Jenkins test-cloudops-cicd-kaniko to deploy v13."
fi

echo
if [[ "$FAIL" -ne 0 ]]; then
  echo "Verification finished with warnings. Apply the fix commands above, then re-run this script."
  exit 1
fi
echo "Verification complete."
echo
echo "Next:"
echo "  bash scripts/verify-cloudops-gateway-release-snapshot.sh"
echo "  bash scripts/verify-cloudops-gateway-canary-observability.sh   # restarts rollout"
echo "  bash scripts/verify-cloudops-gateway-circuit-breaker.sh        # after circuitBreaker sync"
