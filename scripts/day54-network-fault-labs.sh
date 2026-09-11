#!/usr/bin/env bash
# Day 54 network fault labs in namespace cloudops-netlab (isolated).
# Usage:
#   bash scripts/day54-network-fault-labs.sh apply-base
#   bash scripts/day54-network-fault-labs.sh exp1-dns
#   bash scripts/day54-network-fault-labs.sh exp2-svc
#   bash scripts/day54-network-fault-labs.sh exp3-netpol
#   bash scripts/day54-network-fault-labs.sh cleanup
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
      echo "WARN: harbor-pull-secret missing; nginx/curl pull may fail"
    fi
  fi
}

wait_pods() {
  kubectl -n "$NS" wait --for=condition=Ready pod/day54-server pod/day54-client --timeout=180s
}

curl_ok() {
  local url="$1"
  kubectl -n "$NS" exec day54-client -- curl -sS -o /dev/null -w "%{http_code}" --connect-timeout 3 "$url" 2>/dev/null || echo "000"
}

cmd="${1:-}"
case "$cmd" in
  apply-base)
    kubectl apply -f "$LAB/day54-base.yaml"
    ensure_pull_secret
    # re-apply pods if they were created before secret
    kubectl -n "$NS" delete pod day54-server day54-client --ignore-not-found --wait=false || true
    sleep 2
    kubectl apply -f "$LAB/day54-base.yaml"
    wait_pods
    echo "baseline Service:"
    code="$(curl_ok http://day54-server.${NS}.svc.cluster.local/)"
    echo "  GET day54-server svc → HTTP $code (expect 200)"
    ;;
  exp1-dns)
    echo "== EXP1 DNS deny (egress deny-all on client) =="
    echo -n "before resolve+curl: "; curl_ok http://day54-server.${NS}.svc.cluster.local/; echo
    kubectl apply -f "$LAB/day54-dns-deny.yaml"
    sleep 2
    echo -n "after (expect 000 / resolve fail): "; curl_ok http://day54-server.${NS}.svc.cluster.local/; echo
    kubectl -n "$NS" delete -f "$LAB/day54-dns-deny.yaml"
    sleep 2
    echo -n "restored: "; curl_ok http://day54-server.${NS}.svc.cluster.local/; echo
    ;;
  exp2-svc)
    echo "== EXP2 Service wrong selector =="
    kubectl apply -f "$LAB/day54-svc-broken.yaml"
    sleep 1
    echo "endpoints:"; kubectl -n "$NS" get endpoints day54-server day54-server-broken -o wide
    echo -n "good svc: "; curl_ok http://day54-server.${NS}.svc.cluster.local/; echo
    echo -n "broken svc: "; curl_ok http://day54-server-broken.${NS}.svc.cluster.local/; echo " (expect 000)"
    kubectl -n "$NS" delete -f "$LAB/day54-svc-broken.yaml"
    ;;
  exp3-netpol)
    echo "== EXP3 NetworkPolicy deny client→server =="
    echo -n "before: "; curl_ok http://day54-server.${NS}.svc.cluster.local/; echo
    kubectl apply -f "$LAB/day54-netpol-deny.yaml"
    sleep 2
    echo -n "after deny: "; curl_ok http://day54-server.${NS}.svc.cluster.local/; echo " (expect 000)"
    echo "Hubble UI: filter namespace cloudops-netlab — look for dropped/denied"
    kubectl -n "$NS" delete -f "$LAB/day54-netpol-deny.yaml"
    sleep 2
    echo -n "after cleanup: "; curl_ok http://day54-server.${NS}.svc.cluster.local/; echo " (expect 200)"
    ;;
  cleanup)
    kubectl delete ns "$NS" --ignore-not-found --wait=false
    echo "deleted namespace $NS"
    ;;
  all)
    "$0" apply-base
    "$0" exp1-dns
    "$0" exp2-svc
    "$0" exp3-netpol
    echo "Labs done. Run: $0 cleanup   when finished."
    ;;
  *)
    echo "Usage: $0 {apply-base|exp1-dns|exp2-svc|exp3-netpol|all|cleanup}"
    exit 1
    ;;
esac
