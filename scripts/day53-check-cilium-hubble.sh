#!/usr/bin/env bash
# Day 53: Cilium / Hubble / connectivity smoke checks (read-only)
set -euo pipefail

NS_SYS=kube-system
NS_APP=cloudops-dev
HARBOR_HOST="${HARBOR_HOST:-harbor-server.jianggan.cn}"

section() { echo; echo "== $* =="; }

section "Cilium agents / operator"
kubectl -n "$NS_SYS" get ds,deploy -l 'k8s-app in (cilium,cilium-operator),app.kubernetes.io/name=cilium-operator' 2>/dev/null \
  || kubectl -n "$NS_SYS" get ds,deploy | grep -iE 'cilium|NAME' || true
kubectl -n "$NS_SYS" get po -l k8s-app=cilium -o wide 2>/dev/null | head -20 || true
if command -v cilium >/dev/null 2>&1; then
  cilium status --wait=false 2>/dev/null || cilium status 2>/dev/null || true
else
  echo "(cilium CLI not installed; using kubectl only)"
  kubectl -n "$NS_SYS" exec ds/cilium -- cilium status --brief 2>/dev/null || true
fi

section "Hubble peer / relay / ui"
kubectl -n "$NS_SYS" get deploy,ds,svc -l 'k8s-app in (hubble,hubble-relay,hubble-ui)' 2>/dev/null || true
kubectl -n "$NS_SYS" get svc hubble-peer hubble-relay hubble-ui -o wide 2>/dev/null || true
kubectl -n "$NS_SYS" get po -l 'k8s-app in (hubble-relay,hubble-ui)' -o wide 2>/dev/null || \
  kubectl -n "$NS_SYS" get po | grep -i hubble || true

section "CoreDNS"
kubectl -n "$NS_SYS" get po -l k8s-app=kube-dns -o wide 2>/dev/null || true

section "Pod -> Service (in-cluster, from a cloudops-dev pod)"
GW_POD="$(kubectl -n "$NS_APP" get po -l app=cloudops-gateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -n "${GW_POD}" ]]; then
  echo "from pod: $GW_POD"
  kubectl -n "$NS_APP" exec "$GW_POD" -- wget -qO- --timeout=5 http://cloudops-cicd.${NS_APP}.svc.cluster.local/healthz 2>/dev/null \
    && echo " OK pod->cicd svc" || echo " FAIL pod->cicd svc"
  kubectl -n "$NS_APP" exec "$GW_POD" -- wget -qO- --timeout=5 http://kubernetes.default.svc.cluster.local/healthz 2>/dev/null \
    && echo " OK pod->kubernetes svc" || echo " (kubernetes /healthz may 403; connectivity still OK if timeout not hit)"
else
  echo "no cloudops-gateway pod; skip"
fi

section "Pod -> Pod (same ns, via Pod IP)"
CICD_IP="$(kubectl -n "$NS_APP" get po -l app=cloudops-cicd -o jsonpath='{.items[0].status.podIP}' 2>/dev/null || true)"
if [[ -n "${GW_POD}" && -n "${CICD_IP}" ]]; then
  echo "cicd pod IP: $CICD_IP"
  kubectl -n "$NS_APP" exec "$GW_POD" -- wget -qO- --timeout=5 "http://${CICD_IP}:8080/healthz" 2>/dev/null \
    && echo " OK pod->pod IP" || echo " FAIL pod->pod IP"
else
  echo "skip pod->pod"
fi

section "Node / Pod -> Harbor HTTPS"
if kubectl -n "$NS_APP" get po -l app=cloudops-cicd -o name 2>/dev/null | head -1 | grep -q .; then
  CICD_POD="$(kubectl -n "$NS_APP" get po -l app=cloudops-cicd -o jsonpath='{.items[0].metadata.name}')"
  kubectl -n "$NS_APP" exec "$CICD_POD" -- wget -qO- --timeout=8 "https://${HARBOR_HOST}/api/v2.0/health" 2>/dev/null \
    && echo " OK cicd->Harbor API" || echo " FAIL/skip cicd->Harbor (cert or binary may lack TLS tools)"
fi
curl -sk --connect-timeout 5 "https://${HARBOR_HOST}/api/v2.0/health" && echo " OK host->Harbor" || echo " FAIL host->Harbor"

section "Hubble observe sample (optional, needs hubble CLI or relay port-forward)"
if command -v hubble >/dev/null 2>&1; then
  hubble status 2>/dev/null || true
  timeout 8 hubble observe --namespace "$NS_APP" --last 5 2>/dev/null || true
else
  echo "hubble CLI not found. UI: kubectl -n kube-system port-forward svc/hubble-ui 12000:80"
  echo "then open http://127.0.0.1:12000"
fi

section "Summary checklist"
cat <<'EOF'
- [ ] Cilium DaemonSet Ready on all nodes
- [ ] hubble-relay / hubble-ui Running
- [ ] Pod -> Service OK (cloudops-dev)
- [ ] Pod -> Pod IP OK
- [ ] Host/Pod -> Harbor HTTPS OK
- [ ] Hubble UI or hubble observe shows flows
EOF
