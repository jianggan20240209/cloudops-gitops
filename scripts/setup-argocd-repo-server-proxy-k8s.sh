#!/usr/bin/env bash
# Point argocd-repo-server (and application-controller) at the company HTTP proxy
# so repo-server can reach GitHub and clear Application ComparisonError.
#
# Run on harbor-server or any host with kubectl admin access:
#   cd cloudops-gitops && git pull && bash scripts/setup-argocd-repo-server-proxy-k8s.sh
#
# Optional env:
#   PROXY_URL   default http://vv-ai:w16y%2A3w2g862@8.222.223.161:32001
#   ARGOCD_NS   default argocd
#   VERIFY_APP  default cloudops-cicd-dev (set empty to skip Application check)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARGOCD_NS="${ARGOCD_NS:-argocd}"
PROXY_URL="${PROXY_URL:-http://vv-ai:w16y%2A3w2g862@8.222.223.161:32001}"
NO_PROXY="${NO_PROXY:-localhost,127.0.0.1,::1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12,.svc,.cluster.local,.jianggan.cn}"
VERIFY_APP="${VERIFY_APP:-cloudops-cicd-dev}"
DEPLOYS="${DEPLOYS:-argocd-repo-server argocd-application-controller}"
ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT:-600s}"
EXTRA_NO_PROXY="${EXTRA_NO_PROXY:-harbor-server.jianggan.cn,jenkins.jianggan.cn,argocd.jianggan.cn,demo.jianggan.cn,docker.m.daocloud.io,daocloud.io,8.222.223.161,192.168.1.50,192.168.1.200}"

if [[ -z "${HTTP_PROXY:-${http_proxy:-}}" && -f /etc/profile.d/proxy.sh ]]; then
  # shellcheck source=/dev/null
  source /etc/profile.d/proxy.sh
fi

require_kubectl() {
  if ! command -v kubectl >/dev/null 2>&1; then
    echo "ERROR: kubectl not found in PATH" >&2
    exit 1
  fi
  kubectl cluster-info >/dev/null
}

show_proxy_env() {
  local deploy="$1"
  echo "-- ${deploy} current proxy env --"
  kubectl -n "${ARGOCD_NS}" get deploy "${deploy}" \
    -o jsonpath='{range .spec.template.spec.containers[0].env[*]}{.name}={.value}{"\n"}{end}' \
    2>/dev/null | grep -iE '^(HTTP|HTTPS|NO)_PROXY=|^(http|https|no)_proxy=' || echo "(none)"
}

merge_no_proxy() {
  local deploy="$1"
  local existing=""
  existing="$(kubectl -n "${ARGOCD_NS}" get deploy "${deploy}" \
    -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="NO_PROXY")].value}' 2>/dev/null || true)"
  if [[ -z "${existing}" ]]; then
    existing="$(kubectl -n "${ARGOCD_NS}" get deploy "${deploy}" \
      -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="no_proxy")].value}' 2>/dev/null || true)"
  fi
  printf '%s' "${existing},${NO_PROXY},${EXTRA_NO_PROXY}" | tr ',' '\n' | sed '/^$/d' | sort -u | paste -sd, -
}

diagnose_deploy_rollout() {
  local deploy="$1"
  local label="${deploy}"
  echo
  echo "== diagnose ${deploy} rollout =="
  kubectl -n "${ARGOCD_NS}" get deploy "${deploy}" -o wide || true
  kubectl -n "${ARGOCD_NS}" get rs -l "app.kubernetes.io/name=${label}" -o wide 2>/dev/null || \
    kubectl -n "${ARGOCD_NS}" get rs | grep "${deploy}" || true
  kubectl -n "${ARGOCD_NS}" get pods -l "app.kubernetes.io/name=${label}" -o wide 2>/dev/null || \
    kubectl -n "${ARGOCD_NS}" get pods | grep "${deploy}" || true
  local pod
  pod="$(kubectl -n "${ARGOCD_NS}" get pods -l "app.kubernetes.io/name=${label}" \
    --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}' 2>/dev/null || true)"
  if [[ -n "${pod}" ]]; then
    echo "-- describe pod ${pod} (tail) --"
    kubectl -n "${ARGOCD_NS}" describe pod "${pod}" | tail -50 || true
    echo "-- logs pod ${pod} (tail) --"
    kubectl -n "${ARGOCD_NS}" logs "${pod}" --tail=40 2>/dev/null || true
    kubectl -n "${ARGOCD_NS}" logs "${pod}" --previous --tail=40 2>/dev/null || true
  fi
  kubectl -n "${ARGOCD_NS}" get events --field-selector "involvedObject.kind=Pod" --sort-by=.lastTimestamp 2>/dev/null | tail -15 || true
}

patch_deploy_proxy() {
  local deploy="$1"
  local merged_no_proxy
  merged_no_proxy="$(merge_no_proxy "${deploy}")"
  echo
  echo "== patch ${deploy} proxy env =="
  show_proxy_env "${deploy}"
  echo "NO_PROXY merged length: $(printf '%s' "${merged_no_proxy}" | tr ',' '\n' | wc -l)"
  kubectl -n "${ARGOCD_NS}" set env "deployment/${deploy}" \
    HTTP_PROXY="${PROXY_URL}" \
    HTTPS_PROXY="${PROXY_URL}" \
    http_proxy="${PROXY_URL}" \
    https_proxy="${PROXY_URL}" \
    NO_PROXY="${merged_no_proxy}" \
    no_proxy="${merged_no_proxy}"
  if ! kubectl -n "${ARGOCD_NS}" rollout status "deployment/${deploy}" --timeout="${ROLLOUT_TIMEOUT}"; then
    diagnose_deploy_rollout "${deploy}"
    echo "ERROR: ${deploy} rollout timed out (${ROLLOUT_TIMEOUT})" >&2
    return 1
  fi
  show_proxy_env "${deploy}"
}

verify_repo_server_github() {
  local pod
  pod="$(kubectl -n "${ARGOCD_NS}" get pods -l app.kubernetes.io/name=argocd-repo-server \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  if [[ -z "${pod}" ]]; then
    echo "WARN: argocd-repo-server pod not found"
    return 0
  fi
  echo
  echo "== repo-server GitHub connectivity (pod ${pod}) =="
  if kubectl -n "${ARGOCD_NS}" exec "${pod}" -- \
    sh -c "wget -q -O /dev/null --timeout=30 https://github.com 2>/dev/null || curl -fsS -m 30 -I https://github.com >/dev/null"; then
    echo "PASS: repo-server can reach https://github.com"
  else
    echo "WARN: repo-server still cannot reach https://github.com (check proxy / NO_PROXY)"
    kubectl -n "${ARGOCD_NS}" logs "${pod}" --tail=30 || true
  fi
}

refresh_and_wait_app() {
  local app="$1"
  [[ -z "${app}" ]] && return 0

  echo
  echo "== refresh Argo CD Application ${app} =="
  kubectl -n "${ARGOCD_NS}" annotate application "${app}" \
    argocd.argoproj.io/refresh=hard --overwrite
  kubectl -n "${ARGOCD_NS}" patch application "${app}" --type merge \
    -p '{"operation":{"sync":{"revision":"main","prune":true}}}' || true

  local i cond sync health
  for i in $(seq 1 36); do
    cond="$(kubectl -n "${ARGOCD_NS}" get application "${app}" \
      -o jsonpath='{.status.conditions[?(@.type=="ComparisonError")].message}' 2>/dev/null || true)"
    sync="$(kubectl -n "${ARGOCD_NS}" get application "${app}" \
      -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"
    health="$(kubectl -n "${ARGOCD_NS}" get application "${app}" \
      -o jsonpath='{.status.health.status}' 2>/dev/null || true)"
    echo "attempt=${i} sync=${sync:-unknown} health=${health:-unknown} comparisonError=${cond:+yes}"
    if [[ -z "${cond}" && "${sync}" == "Synced" && "${health}" == "Healthy" ]]; then
      echo "PASS: ${app} Synced and Healthy"
      kubectl -n "${ARGOCD_NS}" get application "${app}" \
        -o jsonpath='{.spec.source.helm.parameters[?(@.name=="app.imageTag")].value}{"\n"}'
      return 0
    fi
    if [[ -z "${cond}" && "${sync}" == "Synced" ]]; then
      echo "PASS: ${app} ComparisonError cleared, sync=${sync} health=${health}"
      return 0
    fi
    sleep 5
  done

  echo "WARN: ${app} not fully healthy yet; inspect:"
  kubectl -n "${ARGOCD_NS}" get application "${app}" -o yaml | tail -n 80 || true
  return 0
}

echo "== setup Argo CD repo-server proxy =="
echo "PROXY_URL=${PROXY_URL}"
echo "ARGOCD_NS=${ARGOCD_NS}"
require_kubectl

for deploy in ${DEPLOYS}; do
  if kubectl -n "${ARGOCD_NS}" get deploy "${deploy}" >/dev/null 2>&1; then
    patch_deploy_proxy "${deploy}" || FAILED=1
  else
    echo "SKIP: deployment/${deploy} not found in ${ARGOCD_NS}"
  fi
done

if [[ "${FAILED:-0}" -eq 1 ]]; then
  echo
  echo "Rollout failed. If new pod is Running but slow, wait and check:"
  echo "  kubectl -n ${ARGOCD_NS} rollout status deployment/argocd-repo-server --timeout=600s"
  echo "If stuck Terminating, delete the old pod after new pod is Ready."
  exit 1
fi

verify_repo_server_github
refresh_and_wait_app "${VERIFY_APP}"

echo
echo "PASS: Argo CD repo-server proxy updated."
echo "Re-run Jenkins test-cloudops-cicd-kaniko if imageTag was already patched."
