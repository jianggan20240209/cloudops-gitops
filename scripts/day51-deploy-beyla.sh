#!/usr/bin/env bash
# Day 51: deploy Beyla (cloudops-dev) + Grafana Tempo datasource
# Prerequisites: Day 50 Tempo/Collector Ready; Harbor image library/beyla:2.0.4
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TRACING="$ROOT/dev/platform/observability/tracing"

echo "== ensure harbor-pull-secret in tracing =="
if ! kubectl -n tracing get secret harbor-pull-secret >/dev/null 2>&1; then
  if kubectl -n cloudops-dev get secret harbor-pull-secret >/dev/null 2>&1; then
    kubectl -n cloudops-dev get secret harbor-pull-secret -o yaml \
      | sed 's/namespace: cloudops-dev/namespace: tracing/' \
      | grep -v 'resourceVersion:\|uid:\|creationTimestamp:' \
      | kubectl apply -f -
  elif kubectl -n logging get secret harbor-pull-secret >/dev/null 2>&1; then
    kubectl -n logging get secret harbor-pull-secret -o yaml \
      | sed 's/namespace: logging/namespace: tracing/' \
      | grep -v 'resourceVersion:\|uid:\|creationTimestamp:' \
      | kubectl apply -f -
  else
    echo "WARN: harbor-pull-secret not found; ensure images are pullable"
  fi
fi

echo "== apply Beyla =="
kubectl apply -f "$TRACING/beyla/"

echo "== apply Grafana Tempo datasource =="
kubectl apply -f "$TRACING/grafana/tempo-datasource.yaml"

echo "== wait DaemonSet =="
kubectl -n tracing rollout status daemonset/beyla --timeout=300s

echo "== status =="
kubectl -n tracing get ds,po -l app.kubernetes.io/name=beyla -o wide
kubectl -n monitoring get cm grafana-tempo-datasource

echo
echo "If Tempo datasource missing in UI, restart Grafana:"
echo "  kubectl -n monitoring rollout restart deploy -l app.kubernetes.io/name=grafana"
echo
echo "Generate traffic, then search traces:"
echo "  curl -sk https://cloudops.jianggan.cn/ -o /dev/null -w '%{http_code}\\n'"
echo "  kubectl -n tracing exec deploy/tempo -- wget -qO- 'http://127.0.0.1:3200/api/search?limit=5' || true"
echo
echo "Grafana Explore → Tempo → Search / TraceID"
