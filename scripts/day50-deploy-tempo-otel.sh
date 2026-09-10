#!/usr/bin/env bash
# Day 50: deploy Tempo + OTel Collector into namespace tracing
# Prerequisites: images in Harbor (see docs), longhorn StorageClass
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TRACING="$ROOT/dev/platform/observability/tracing"

echo "== apply namespace =="
kubectl apply -f "$TRACING/namespace.yaml"

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

echo "== apply tempo =="
kubectl apply -f "$TRACING/tempo/"

echo "== apply otel-collector =="
kubectl apply -f "$TRACING/otel-collector/"

echo "== wait =="
kubectl -n tracing rollout status deploy/tempo --timeout=300s
kubectl -n tracing rollout status deploy/otel-collector --timeout=300s

echo "== status =="
kubectl -n tracing get pvc,po,svc

echo
echo "OTLP gRPC: otel-collector.tracing.svc.cluster.local:4317"
echo "OTLP HTTP: otel-collector.tracing.svc.cluster.local:4318"
echo "Tempo API: tempo.tracing.svc.cluster.local:3200"
echo
echo "Health check:"
echo "  kubectl -n tracing exec deploy/otel-collector -- wget -qO- http://127.0.0.1:13133/ || true"
echo "  kubectl -n tracing exec deploy/tempo -- wget -qO- http://127.0.0.1:3200/ready || true"
