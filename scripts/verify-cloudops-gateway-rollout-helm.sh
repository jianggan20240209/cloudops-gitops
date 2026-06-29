#!/usr/bin/env bash
# Verify cloudops-gateway-rollout Helm migration and trafficPolicy sync.
set -euo pipefail

APP="cloudops-gateway-rollout-dev"
NS="cloudops-dev"
NAME="cloudops-gateway-rollout"

echo "== Argo CD Application =="
kubectl -n argocd get application "$APP" \
  -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,REVISION:.status.sync.revision

echo
echo "== Helm source =="
kubectl -n argocd get application "$APP" -o jsonpath='{.spec.source.path}{"\n"}{.spec.source.helm.valueFiles}{"\n"}'

echo
echo "== Rollout / Istio resources =="
kubectl -n "$NS" get rollout,svc,gateway,virtualservice,destinationrule,servicemonitor -l "app.kubernetes.io/name=$NAME"

echo
echo "== VirtualService weights / timeout =="
kubectl -n "$NS" get virtualservice "$NAME" -o yaml | grep -E 'weight:|timeout:|attempts:|retryOn:'

echo
echo "== API health =="
curl -k -fsS "https://api.cloudops.jianggan.cn/readyz"
echo
curl -k -fsS "https://api.cloudops.jianggan.cn/api/v1/version"
echo

echo
echo "== cloudops-cicd traffic =="
curl -k -fsS "https://cloudops.jianggan.cn/api/v1/cicd/apps/$NAME/traffic" | head -c 2000
echo

echo
echo "Verification complete."
