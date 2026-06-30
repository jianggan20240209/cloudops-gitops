#!/usr/bin/env bash
# Configure git proxy for Jenkins controller SCM fetch (run ON Jenkins controller).
set -euo pipefail

GIT_PROXY="${GIT_PROXY:-http://192.168.1.50:7890}"
REPO_URL="${REPO_URL:-https://github.com/jianggan20240209/cloudops-platform.git}"
JENKINS_HOME="${JENKINS_HOME:-${HOME}}"

echo "== Jenkins controller git proxy setup =="
echo "GIT_PROXY=${GIT_PROXY}"
echo "JENKINS_HOME=${JENKINS_HOME}"

export HOME="${JENKINS_HOME}"

git config --global http.proxy "${GIT_PROXY}"
git config --global https.proxy "${GIT_PROXY}"
git config --global http.version HTTP/1.1
git config --global http.lowSpeedLimit 0
git config --global http.lowSpeedTime 999999

echo
echo "== git config =="
git config --global --list | grep -E 'proxy|http.version|lowSpeed' || true

echo
echo "== proxy connectivity =="
if curl -fsS -x "${GIT_PROXY}" -I https://github.com >/dev/null; then
  echo "PASS: curl via proxy can reach github.com"
else
  echo "WARN: curl via proxy failed to reach github.com"
fi

echo
echo "== git ls-remote =="
if git ls-remote "${REPO_URL}" HEAD; then
  echo "PASS: git can fetch ${REPO_URL}"
else
  echo "FAIL: git cannot fetch ${REPO_URL}"
  echo "If Jenkins runs in a container, run this script inside the Jenkins controller pod with JENKINS_HOME=/var/jenkins_home"
  exit 1
fi

echo
echo "Done. Retry Jenkins job test-cloudops-cicd-kaniko."
