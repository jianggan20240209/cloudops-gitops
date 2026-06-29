#!/usr/bin/env bash
# Discover Istio metric labels in Prometheus for cloudops-gateway-rollout.
set -euo pipefail

PROM="${PROMETHEUS_SERVER:-http://kube-prometheus-stack-prometheus.monitoring.svc:9090}"
APP="${1:-cloudops-gateway-rollout}"
NS="${2:-cloudops-dev}"

query() {
  curl -fsS "${PROM}/api/v1/query" --data-urlencode "query=$1" | head -c 4000
  echo
}

echo "== istio_requests_total series containing ${APP} =="
query "topk(20, sum by (destination_service_name, destination_service, destination_workload, source_workload) (rate(istio_requests_total[5m])))" \
  | grep -i "${APP}" || true

echo
echo "== candidate selectors =="
for q in \
  "sum(rate(istio_requests_total{destination_service_name=~\"${APP}-.*\"}[5m]))" \
  "sum(rate(istio_requests_total{destination_service=~\"${APP}-.*\\.${NS}\\\\.svc\\\\.cluster\\\\.local\"}[5m]))" \
  "sum(rate(istio_requests_total{source_workload=\"istio-ingressgateway\",destination_service=~\"${APP}-.*\\.${NS}\\\\.svc\\\\.cluster\\\\.local\"}[5m]))"
do
  echo "-- ${q}"
  query "${q}"
done
