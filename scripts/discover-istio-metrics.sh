#!/usr/bin/env bash
# Discover Istio metric labels in Prometheus for cloudops-gateway-rollout.
set -euo pipefail

PROM="${PROMETHEUS_SERVER:-http://kube-prometheus-stack-prometheus.monitoring.svc:9090}"
APP="${1:-cloudops-gateway-rollout}"
NS="${2:-cloudops-dev}"

query() {
  curl -fsS "${PROM}/api/v1/query" --data-urlencode "query=$1"
  echo
}

echo "== istio metric families =="
query 'count({__name__=~"istio_.*"})' | head -c 2000
echo

echo "== istio_requests_total present =="
query 'count(istio_requests_total)' | head -c 2000
echo

echo "== PodMonitor in istio-ingress =="
kubectl -n istio-ingress get podmonitor istio-ingressgateway 2>/dev/null || \
  echo "PodMonitor istio-ingressgateway not found (apply istio-ingressgateway-monitor-dev)"

echo
echo "== gateway pod labels =="
kubectl -n istio-ingress get pod -l app=istio-ingressgateway,istio=ingressgateway \
  --show-labels 2>/dev/null | head -n 5 || true

echo
echo "== istio_requests_total series containing ${APP} =="
query "topk(20, sum by (destination_service_name, destination_service, destination_service_namespace, destination_workload, source_workload) (rate(istio_requests_total[5m])))" \
  | grep -i "${APP}" || echo "(no series matched app name in topk output)"

echo
echo "== candidate selectors =="
for q in \
  "sum(rate(istio_requests_total{destination_service_name=~\"${APP}-.*\"}[5m]))" \
  "sum(rate(istio_requests_total{destination_service=~\"${APP}-.*\\.${NS}\\\\.svc\\\\.cluster\\\\.local\"}[5m]))" \
  "sum(rate(istio_requests_total{source_workload=\"istio-ingressgateway\",destination_service_namespace=\"${NS}\",destination_service=~\"${APP}-.*\"}[5m]))" \
  "sum(rate(istio_requests_total{source_workload=\"istio-ingressgateway\"}[5m]))"
do
  echo "-- ${q}"
  query "${q}" | head -c 1500
  echo
done
