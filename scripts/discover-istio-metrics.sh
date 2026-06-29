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
echo "== PodMonitor + ServiceMonitor (expect namespace monitoring) =="
kubectl -n monitoring get podmonitor,servicemonitor istio-ingressgateway 2>/dev/null || \
  echo "Monitor resources not found in monitoring namespace"
kubectl -n istio-ingress get podmonitor istio-ingressgateway 2>/dev/null && \
  echo "WARN: legacy PodMonitor still in istio-ingress; delete after sync to monitoring"

echo
echo "== gateway pod labels =="
kubectl -n istio-ingress get pod -l istio=ingressgateway --show-labels 2>/dev/null | head -n 5 || true

echo
echo "== gateway local metrics endpoint =="
GW_POD="$(kubectl -n istio-ingress get pod -l istio=ingressgateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -n "${GW_POD}" ]]; then
  for port in 15090 15020; do
    echo "-- pod ${GW_POD}:${port}/stats/prometheus"
    kubectl -n istio-ingress exec "${GW_POD}" -c istio-proxy -- \
      sh -c "command -v curl >/dev/null && curl -fsS http://127.0.0.1:${port}/stats/prometheus | grep -m1 'istio_requests_total' || wget -qO- http://127.0.0.1:${port}/stats/prometheus | grep -m1 'istio_requests_total'" \
      2>/dev/null | head -n1 || echo "no istio_requests_total on localhost:${port}"
  done
else
  echo "gateway pod not found"
fi

echo
echo "== prometheus scrape targets (gateway) =="
query 'up{namespace="istio-ingress",pod=~"istio-ingressgateway.*"}' | head -c 2000
echo
query 'up{namespace="istio-ingress",service="istio-ingressgateway"}' | head -c 2000
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
echo "== candidate selectors (before traffic) =="
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

echo
echo "== generate ingress traffic (30x /readyz) =="
for _ in $(seq 1 30); do
  curl -k -s https://api.cloudops.jianggan.cn/readyz >/dev/null || true
done
echo "done"

echo
echo "== candidate selectors (after traffic, wait 15s for scrape) =="
sleep 15
for q in \
  "sum(rate(istio_requests_total{destination_service_name=~\"${APP}-.*\"}[1m]))" \
  "sum(rate(istio_requests_total{source_workload=\"istio-ingressgateway\",destination_service_namespace=\"${NS}\",destination_service=~\"${APP}-.*\"}[1m]))"
do
  echo "-- ${q}"
  query "${q}" | head -c 1500
  echo
done

echo
echo "== gateway service ports (expect http-envoy-prom) =="
kubectl -n istio-ingress get svc istio-ingressgateway -o jsonpath='{.spec.ports[*].name}{"\n"}' 2>/dev/null || true
