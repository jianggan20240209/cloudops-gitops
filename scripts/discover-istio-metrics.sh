#!/usr/bin/env bash
# Discover Istio metric labels in Prometheus for cloudops-gateway-rollout.
set -euo pipefail

PROM="${PROMETHEUS_SERVER:-http://kube-prometheus-stack-prometheus.monitoring.svc:9090}"
APP="${1:-cloudops-gateway-rollout}"
NS="${2:-cloudops-dev}"
RUN_ID="istio-discover-$$"

cleanup() {
  kubectl -n monitoring delete pod "curl-prom-${RUN_ID}" --ignore-not-found >/dev/null 2>&1 || true
}
trap cleanup EXIT

query_in_cluster() {
  local prom_query="$1"
  kubectl -n monitoring run "curl-prom-${RUN_ID}" \
    --rm -i --restart=Never \
    --image=curlimages/curl:8.16.0 \
    --command -- \
    curl -fsS "${PROM}/api/v1/query" --data-urlencode "query=${prom_query}"
}

query() {
  if curl -fsS --max-time 3 "${PROM}/api/v1/query" --data-urlencode "query=$1" >/dev/null 2>&1; then
    curl -fsS "${PROM}/api/v1/query" --data-urlencode "query=$1"
    echo
    return
  fi
  echo "(query via kubectl run in monitoring namespace)"
  query_in_cluster "$1"
  echo
}

echo "== Argo CD PodMonitor application =="
kubectl -n argocd get application istio-ingressgateway-monitor-dev \
  -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status 2>/dev/null || \
  echo "Application istio-ingressgateway-monitor-dev not found"

echo
echo "== PodMonitor (expect namespace monitoring) =="
kubectl -n monitoring get podmonitor istio-ingressgateway 2>/dev/null || \
  echo "PodMonitor not found in monitoring namespace"
kubectl -n istio-ingress get podmonitor istio-ingressgateway 2>/dev/null && \
  echo "WARN: legacy PodMonitor still in istio-ingress; delete after sync to monitoring"

echo
echo "== gateway pod labels =="
kubectl -n istio-ingress get pod -l istio=ingressgateway --show-labels 2>/dev/null | head -n 5 || true

echo
echo "== gateway local metrics endpoint =="
GW_POD="$(kubectl -n istio-ingress get pod -l istio=ingressgateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -n "${GW_POD}" ]]; then
  kubectl -n istio-ingress exec "${GW_POD}" -c istio-proxy -- \
    wget -qO- http://127.0.0.1:15020/stats/prometheus 2>/dev/null | grep -m1 'istio_requests_total' || \
    echo "istio_requests_total not found on gateway :15020 (check istio-proxy container)"
else
  echo "gateway pod not found"
fi

echo
echo "== prometheus scrape target for gateway =="
query "up{namespace=\"istio-ingress\",pod=~\"istio-ingressgateway.*\"}" | head -c 2000
echo

echo "== envoy metrics from gateway pod =="
query "count({__name__=~\"envoy_.*\",namespace=\"istio-ingress\",pod=~\"istio-ingressgateway.*\"})" | head -c 2000
echo

echo "== istio metric families =="
query 'count({__name__=~"istio_.*"})' | head -c 2000
echo

echo "== istio_requests_total present =="
query 'count(istio_requests_total)' | head -c 2000
echo

echo "== istio_requests_total series containing ${APP} =="
query "topk(20, sum by (destination_service_name, destination_service, destination_service_namespace, destination_workload, source_workload) (rate(istio_requests_total[5m])))" \
  | grep -i "${APP}" || echo "(no series matched app name in topk output)"

echo
echo "== candidate selectors =="
for q in \
  "sum(rate(istio_requests_total{destination_service_name=~\"${APP}-.*\"}[5m]))" \
  "sum(rate(istio_requests_total{destination_service=~\"${APP}-.*${NS}.svc.cluster.local\"}[5m]))" \
  "sum(rate(istio_requests_total{source_workload=\"istio-ingressgateway\",destination_service_namespace=\"${NS}\",destination_service=~\"${APP}-.*\"}[5m]))" \
  "sum(rate(istio_requests_total{source_workload=\"istio-ingressgateway\"}[5m]))"
do
  echo "-- ${q}"
  query "${q}" | head -c 1500
  echo
done
