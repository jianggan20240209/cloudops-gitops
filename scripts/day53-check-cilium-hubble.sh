#!/usr/bin/env bash
# Day 53: Cilium / Hubble / connectivity smoke checks (read-only)
# Note: cloudops-gateway/cicd are scratch images (no wget); use a debug curl pod for probes.
set -euo pipefail

NS_SYS=kube-system
NS_APP=cloudops-dev
HARBOR_HOST="${HARBOR_HOST:-harbor-server.jianggan.cn}"
DEBUG_IMAGE="${DEBUG_IMAGE:-harbor-server.jianggan.cn/library/curl:8.16.0}"

section() { echo; echo "== $* =="; }

section "Cilium agents"
kubectl -n "$NS_SYS" get po -l k8s-app=cilium -o wide 2>/dev/null | head -20 || true
READY="$(kubectl -n "$NS_SYS" get po -l k8s-app=cilium --no-headers 2>/dev/null | awk '$2=="1/1"{c++} END{print c+0}')"
TOTAL="$(kubectl -n "$NS_SYS" get po -l k8s-app=cilium --no-headers 2>/dev/null | wc -l | tr -d ' ')"
echo "cilium Ready ${READY}/${TOTAL}"

section "Hubble peer / relay / ui"
kubectl -n "$NS_SYS" get deploy hubble-relay hubble-ui 2>/dev/null || true
kubectl -n "$NS_SYS" get svc hubble-peer hubble-relay hubble-ui -o wide 2>/dev/null || true
kubectl -n "$NS_SYS" get po -l 'k8s-app in (hubble-relay,hubble-ui)' -o wide 2>/dev/null || \
  kubectl -n "$NS_SYS" get po | grep -i hubble || true

section "CoreDNS"
kubectl -n "$NS_SYS" get po -l k8s-app=kube-dns -o wide 2>/dev/null || true

section "Connectivity via debug curl pod (not scratch app images)"
kubectl -n "$NS_APP" delete pod day53-netcheck --ignore-not-found --wait=false >/dev/null 2>&1 || true
kubectl -n "$NS_APP" run day53-netcheck --restart=Never --image="$DEBUG_IMAGE" \
  --overrides='{"spec":{"imagePullSecrets":[{"name":"harbor-pull-secret"}]}}' \
  --command -- sleep 600 >/dev/null
kubectl -n "$NS_APP" wait --for=condition=Ready pod/day53-netcheck --timeout=120s

echo "-- DNS cloudops-cicd --"
kubectl -n "$NS_APP" exec day53-netcheck -- \
  curl -sS -o /dev/null -w "cicd_svc %{http_code}\n" --connect-timeout 5 \
  "http://cloudops-cicd.${NS_APP}.svc.cluster.local/healthz" || echo "FAIL cicd_svc"

echo "-- DNS cloudops-gateway --"
kubectl -n "$NS_APP" exec day53-netcheck -- \
  curl -sS -o /dev/null -w "gateway_svc %{http_code}\n" --connect-timeout 5 \
  "http://cloudops-gateway.${NS_APP}.svc.cluster.local/healthz" || echo "FAIL gateway_svc"

CICD_IP="$(kubectl -n "$NS_APP" get po -l app=cloudops-cicd -o jsonpath='{.items[0].status.podIP}' 2>/dev/null || true)"
if [[ -n "${CICD_IP}" ]]; then
  echo "-- Pod IP cicd ${CICD_IP}:8080 --"
  kubectl -n "$NS_APP" exec day53-netcheck -- \
    curl -sS -o /dev/null -w "cicd_pod %{http_code}\n" --connect-timeout 5 \
    "http://${CICD_IP}:8080/healthz" || echo "FAIL cicd_pod"
fi

echo "-- Harbor HTTPS --"
kubectl -n "$NS_APP" exec day53-netcheck -- \
  curl -skS -o /dev/null -w "harbor_from_pod %{http_code}\n" --connect-timeout 8 \
  "https://${HARBOR_HOST}/api/v2.0/health" || echo "FAIL harbor_from_pod"
curl -skS --connect-timeout 5 "https://${HARBOR_HOST}/api/v2.0/health" >/dev/null \
  && echo "harbor_from_host OK" || echo "FAIL harbor_from_host"

kubectl -n "$NS_APP" delete pod day53-netcheck --ignore-not-found --wait=false >/dev/null 2>&1 || true

section "Hubble UI hint"
cat <<'EOF'
# Correct port-forward (local only):
kubectl -n kube-system port-forward svc/hubble-ui 12000:80
# Open http://127.0.0.1:12000  (from harbor-server browser / SSH tunnel)

# Wrong: do NOT put host IP as a port name
# kubectl ... port-forward svc/hubble-ui 192.168.1.200 12000:80
EOF

section "Summary"
cat <<EOF
- Cilium Ready: ${READY}/${TOTAL}
- hubble-relay / hubble-ui: see above
- Connectivity: see curl http_code lines (expect 200)
- Harbor host: OK if harbor_from_host OK
EOF
