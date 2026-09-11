#!/usr/bin/env bash
# Day 51 one-shot on harbor-server (mirror + deploy + smoke)
# Usage: cd ~/code/cloudops-gitops && bash scripts/day51-run-all-on-harbor.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== sync working tree tip (optional) =="
git rev-parse --short HEAD || true
git log -1 --oneline || true

echo "== mirror Beyla image =="
bash "$ROOT/scripts/day51-mirror-beyla-image.sh"

echo "== deploy Beyla + Tempo datasource =="
bash "$ROOT/scripts/day51-deploy-beyla.sh"

echo "== generate sample traffic =="
curl -sk "https://cloudops.jianggan.cn/" -o /dev/null -w "cloudops-web %{http_code}\n" || true
curl -sk "https://api.cloudops.jianggan.cn/healthz" -o /dev/null -w "gateway %{http_code}\n" || true
sleep 8

echo "== Tempo search (best-effort) =="
kubectl -n tracing exec deploy/tempo -- \
  wget -qO- "http://127.0.0.1:3200/api/search?limit=5" || true
echo

echo "== Beyla pods =="
kubectl -n tracing get ds,po -l app.kubernetes.io/name=beyla -o wide

echo
echo "Next: Grafana Explore → Tempo → Search"
echo "Then mark docs Ready and push from Windows if needed."
