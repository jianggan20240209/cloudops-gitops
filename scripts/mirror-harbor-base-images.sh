#!/usr/bin/env bash
# Mirror Docker Hub base images into Harbor for Kaniko builds (cluster cannot reach docker.io).
# Run on harbor-server (or any host with docker + harbor login + outbound proxy).
set -euo pipefail

HARBOR="${HARBOR:-harbor-server.jianggan.cn}"
PROJECT="${PROJECT:-base}"
PROXY="${HTTP_PROXY:-http://192.168.1.50:7890}"

IMAGES=(
  "golang:1.23-alpine"
  "nginx:1.27-alpine"
)

echo "Harbor project: ${HARBOR}/${PROJECT}"
echo "Pull proxy: ${PROXY}"
echo "Ensure Harbor project '${PROJECT}' exists and your docker client is logged in."
echo

for src in "${IMAGES[@]}"; do
  name="${src%%:*}"
  tag="${src##*:}"
  dest="${HARBOR}/${PROJECT}/${name}:${tag}"
  echo "== ${src} -> ${dest} =="
  HTTP_PROXY="${PROXY}" HTTPS_PROXY="${PROXY}" http_proxy="${PROXY}" https_proxy="${PROXY}" \
    docker pull "${src}"
  docker tag "${src}" "${dest}"
  docker push "${dest}"
  echo
done

echo "PASS: base images mirrored to ${HARBOR}/${PROJECT}/"
