#!/usr/bin/env bash
# Day 61 fault drills — run on harbor-server with cluster access.
# Usage: bash scripts/day61-fault-drills.sh {oom|http500|redis-down|redis-up|status|cleanup}
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NS_DEV=cloudops-dev
NS_FL=cloudops-faultlab

cmd="${1:-status}"

apply_base() {
  kubectl apply -f "$ROOT/dev/platform/observability/faultlab/day61-workloads.yaml"
}

case "$cmd" in
  status)
    apply_base || true
    kubectl -n "$NS_DEV" get deploy,po,svc -l app=day61-redis || true
    kubectl -n "$NS_FL" get deploy,po -l app=day61-oom-demo || true
    ;;
  oom)
    apply_base
    kubectl -n "$NS_FL" scale deploy/day61-oom-demo --replicas=1
    echo "Watch: kubectl -n $NS_FL get po -w"
    echo "Expect OOMKilled / CrashLoop; alert KubePodOOMKilled may fire after metric scrape."
    ;;
  http500)
    echo "== Force gateway 5xx traffic (needs working ingress) =="
    for i in $(seq 1 30); do
      curl -sk -o /dev/null -w "%{http_code}\n" \
        -H "X-Fault-Inject: 500" \
        "https://cloudops.jianggan.cn/api/v1/version" || true
    done
    echo "If gateway has no fault header, scale cicd to 0 briefly or break upstream — see docs."
    echo "Alternative: kubectl -n $NS_DEV scale deploy/cloudops-cicd --replicas=0  # then restore"
    ;;
  redis-down)
    apply_base
    kubectl -n "$NS_DEV" scale deploy/day61-redis --replicas=0
    echo "Redis scaled to 0. Restore with: bash $0 redis-up"
    ;;
  redis-up)
    kubectl -n "$NS_DEV" scale deploy/day61-redis --replicas=1
    kubectl -n "$NS_DEV" rollout status deploy/day61-redis --timeout=120s
    ;;
  cleanup)
    kubectl -n "$NS_FL" scale deploy/day61-oom-demo --replicas=0 || true
    kubectl -n "$NS_DEV" scale deploy/day61-redis --replicas=0 || true
    echo "Scaled drills to 0. Delete ns/resources manually if desired."
    ;;
  *)
    echo "usage: $0 {oom|http500|redis-down|redis-up|status|cleanup}"
    exit 1
    ;;
esac
