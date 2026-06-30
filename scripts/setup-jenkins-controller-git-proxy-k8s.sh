#!/usr/bin/env bash
# Run Jenkins controller git proxy setup inside the Jenkins pod via kubectl.
set -euo pipefail

GIT_PROXY="${GIT_PROXY:-http://192.168.1.50:7890}"
REPO_URL="${REPO_URL:-https://github.com/jianggan20240209/cloudops-platform.git}"
JENKINS_NS="${JENKINS_NS:-}"
JENKINS_POD="${JENKINS_POD:-}"

find_jenkins_pod() {
  if [[ -n "${JENKINS_NS}" && -n "${JENKINS_POD}" ]]; then
    echo "${JENKINS_NS} ${JENKINS_POD}"
    return 0
  fi

  local line
  line="$(kubectl get pods -A 2>/dev/null | awk 'tolower($0) ~ /jenkins/ && $4 == "Running" {print $1, $2; exit}')"
  if [[ -n "${line}" ]]; then
    echo "${line}"
    return 0
  fi

  return 1
}

echo "== locate Jenkins controller pod =="
if ! read -r NS POD < <(find_jenkins_pod); then
  echo "ERROR: Jenkins pod not found. Set JENKINS_NS and JENKINS_POD explicitly."
  echo "Example:"
  echo "  kubectl get pods -A | grep -i jenkins"
  echo "  JENKINS_NS=jenkins JENKINS_POD=jenkins-0 bash $0"
  exit 1
fi

echo "Using namespace=${NS} pod=${POD}"

echo
echo "== run git proxy setup inside Jenkins pod =="
kubectl -n "${NS}" exec "${POD}" -- bash -s <<EOF
set -euo pipefail
export JENKINS_HOME=/var/jenkins_home
export HOME=/var/jenkins_home
mkdir -p "\${JENKINS_HOME}"

GIT_PROXY="${GIT_PROXY}"
REPO_URL="${REPO_URL}"

echo "GIT_PROXY=\${GIT_PROXY}"
echo "JENKINS_HOME=\${JENKINS_HOME}"

git config --global http.proxy "\${GIT_PROXY}"
git config --global https.proxy "\${GIT_PROXY}"
git config --global http.version HTTP/1.1
git config --global http.lowSpeedLimit 0
git config --global http.lowSpeedTime 999999

echo
echo "== git config =="
git config --global --list | grep -E 'proxy|http.version|lowSpeed' || true

echo
echo "== proxy connectivity =="
if command -v curl >/dev/null 2>&1; then
  if curl -fsS -x "\${GIT_PROXY}" -I https://github.com >/dev/null; then
    echo "PASS: curl via proxy can reach github.com"
  else
    echo "WARN: curl via proxy failed to reach github.com"
  fi
else
  echo "INFO: curl not found in Jenkins pod"
fi

echo
echo "== git ls-remote =="
git ls-remote "\${REPO_URL}" HEAD
EOF

echo
echo "PASS: Jenkins controller git proxy configured in pod ${NS}/${POD}"
echo "Next: Manage Jenkins -> System -> HTTP Proxy = 192.168.1.50:7890, then retry test-cloudops-cicd-kaniko"
