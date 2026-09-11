#!/usr/bin/env bash
# Day 64 — security baseline quick check (harbor-server)
set -euo pipefail
echo "== namespaces PSA labels =="
kubectl get ns cloudops-dev monitoring logging tracing --show-labels 2>/dev/null || true
echo "== cluster-admin bindings (should be few) =="
kubectl get clusterrolebinding -o custom-columns=NAME:.metadata.name,ROLE:.roleRef.name,SUBJECTS:.subjects[*].name 2>/dev/null | grep -i cluster-admin || true
echo "== secrets in cloudops-dev (names only) =="
kubectl -n cloudops-dev get secrets --no-headers 2>/dev/null | awk '{print $1,$2}' | head
echo "== networkpolicies =="
kubectl get networkpolicy -A 2>/dev/null | head -30
echo "== ingress TLS hosts =="
kubectl get ingress -A -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,HOSTS:.spec.rules[*].host,TLS:.spec.tls[*].hosts 2>/dev/null | head -40
echo "Done. Review against docs/day64-k8s-security-baseline.md"
