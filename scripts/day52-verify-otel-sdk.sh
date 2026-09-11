#!/usr/bin/env bash
# Day 52 smoke: OTel env + Tempo resource attrs + traffic
set -euo pipefail

NS=cloudops-dev

echo "== gateway/cicd otel env =="
kubectl -n "$NS" get deploy cloudops-gateway cloudops-cicd -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .spec.template.spec.containers[0].env[*]}{.name}{"="}{.value}{"\n"}{end}{"\n"}{end}' \
  | grep -E '^(cloudops-|OTEL_|SERVICE_VERSION|DEPLOYMENT_)' || true

echo "== recent otel_enabled logs =="
kubectl -n "$NS" logs -l app=cloudops-gateway --tail=50 2>/dev/null | grep otel_enabled || true
kubectl -n "$NS" logs -l app=cloudops-cicd --tail=50 2>/dev/null | grep otel_enabled || true

echo "== traffic =="
curl -sk "https://api.cloudops.jianggan.cn/api/v1/version" -D - -o /tmp/gw-version.json | tr -d '\r' | grep -iE '^(HTTP/|x-trace-id|x-request-id)' || true
cat /tmp/gw-version.json 2>/dev/null || true
echo
curl -sk "https://cloudops.jianggan.cn/api/v1/cicd/apps" -o /dev/null -w "cicd_apps %{http_code}\n" || true
sleep 8

echo "== Tempo search (gateway/cicd) =="
kubectl -n tracing exec deploy/tempo -- wget -qO- "http://127.0.0.1:3200/api/search?limit=10" || true
echo
echo "Grafana Explore → Tempo → filter service.name = cloudops-gateway|cloudops-cicd"
echo "Check Resource: service.version, deployment.id"
