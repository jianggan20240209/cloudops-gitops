#!/usr/bin/env bash
# Day 54 network fault labs in namespace cloudops-netlab (isolated).
# Usage: bash scripts/day54-network-fault-labs.sh {apply-base|exp1-dns|exp2-svc|exp3-netpol|all|cleanup}
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LAB="$ROOT/dev/platform/observability/netlab"
NS=cloudops-netlab
SELF="$ROOT/scripts/day54-network-fault-labs.sh"

ensure_pull_secret() {
  if ! kubectl -n "$NS" get secret harbor-pull-secret >/dev/null 2>&1; then
    if kubectl -n cloudops-dev get secret harbor-pull-secret >/dev/null 2>&1; then
      kubectl -n cloudops-dev get secret harbor-pull-secret -o yaml \
        | sed "s/namespace: cloudops-dev/namespace: $NS/" \
        | grep -v 'resourceVersion:\|uid:\|creationTimestamp:' \
        | kubectl apply -f -
    else
      echo "WARN: harbor-pull-secret missing; image pull may fail"
    fi
  fi
}

diag() {
  echo "--- diag ---"
  kubectl -n "$NS" get po -o wide
  kubectl -n "$NS" get svc,endpointslices -o wide 2>/dev/null || kubectl -n "$NS" get svc,ep -o wide
  kubectl -n "$NS" logs day54-server --tail=15 2>/dev/null || true
}

curl_ok() {
  local url="$1"
  local out ec=0
  out="$(kubectl -n "$NS" exec day54-client -- \
    curl -sS -o /dev/null -w "%{http_code}" --connect-timeout 5 "$url" 2>/dev/null)" || ec=$?
  if [[ "$ec" -ne 0 || -z "$out" ]]; then
    printf '%s' "000"
  else
    printf '%s' "$out"
  fi
}

wait_ready() {
  kubectl -n "$NS" wait --for=condition=Ready pod/day54-server pod/day54-client --timeout=180s
  # wait until EndpointSlice has an address
  for i in $(seq 1 30); do
    addrs="$(kubectl -n "$NS" get endpointslices -l kubernetes.io/service-name=day54-server \
      -o jsonpath='{.items[*].endpoints[*].addresses[*]}' 2>/dev/null || true)"
    if [[ -n "${addrs}" ]]; then
      echo "EndpointSlice addresses: ${addrs}"
      return 0
    fi
    sleep 2
  done
  echo "ERROR: day54-server still has no EndpointSlice addresses"
  diag
  return 1
}

cmd="${1:-}"
case "$cmd" in
  apply-base)
    kubectl apply -f "$LAB/day54-base.yaml"
    ensure_pull_secret
    # restart pods once so they pick up pull secret if created late
    kubectl -n "$NS" delete pod day54-server day54-client --ignore-not-found --wait=true || true
    kubectl apply -f "$LAB/day54-base.yaml"
    wait_ready
    diag
    echo "baseline Service:"
    code="$(curl_ok "http://day54-server.${NS}.svc.cluster.local/")"
    echo "  GET day54-server svc → HTTP ${code} (expect 200)"
    if [[ "$code" != "200" ]]; then
      echo "ERROR: baseline failed; fix image/network before experiments"
      kubectl -n "$NS" exec day54-client -- curl -v --connect-timeout 5 \
        "http://day54-server.${NS}.svc.cluster.local/" || true
      exit 1
    fi
    ;;
  exp1-dns)
    echo "== EXP1 DNS deny (egress deny-all on client) =="
    echo -n "before: "; curl_ok "http://day54-server.${NS}.svc.cluster.local/"; echo
    kubectl apply -f "$LAB/day54-dns-deny.yaml"
    sleep 2
    echo -n "after (expect 000): "; curl_ok "http://day54-server.${NS}.svc.cluster.local/"; echo
    kubectl -n "$NS" delete -f "$LAB/day54-dns-deny.yaml"
    sleep 2
    echo -n "restored (expect 200): "; curl_ok "http://day54-server.${NS}.svc.cluster.local/"; echo
    ;;
  exp2-svc)
    echo "== EXP2 Service wrong selector =="
    kubectl apply -f "$LAB/day54-svc-broken.yaml"
    sleep 1
    echo "endpoint slices:"
    kubectl -n "$NS" get endpointslices -o wide
    echo -n "good svc (expect 200): "; curl_ok "http://day54-server.${NS}.svc.cluster.local/"; echo
    echo -n "broken svc (expect 000): "; curl_ok "http://day54-server-broken.${NS}.svc.cluster.local/"; echo
    kubectl -n "$NS" delete -f "$LAB/day54-svc-broken.yaml"
    ;;
  exp3-netpol)
    echo "== EXP3 NetworkPolicy deny client→server =="
    echo -n "before (expect 200): "; curl_ok "http://day54-server.${NS}.svc.cluster.local/"; echo
    kubectl apply -f "$LAB/day54-netpol-deny.yaml"
    sleep 2
    echo -n "after deny (expect 000): "; curl_ok "http://day54-server.${NS}.svc.cluster.local/"; echo
    echo "Hubble UI: namespace=cloudops-netlab — look for dropped/denied"
    kubectl -n "$NS" delete -f "$LAB/day54-netpol-deny.yaml"
    sleep 2
    echo -n "after cleanup (expect 200): "; curl_ok "http://day54-server.${NS}.svc.cluster.local/"; echo
    ;;
  cleanup)
    kubectl delete ns "$NS" --ignore-not-found --wait=false
    echo "deleted namespace $NS"
    ;;
  all)
    bash "$SELF" apply-base
    bash "$SELF" exp1-dns
    bash "$SELF" exp2-svc
    bash "$SELF" exp3-netpol
    echo "Labs done. Next: bash $SELF cleanup"
    ;;
  *)
    echo "Usage: bash $SELF {apply-base|exp1-dns|exp2-svc|exp3-netpol|all|cleanup}"
    exit 1
    ;;
esac
