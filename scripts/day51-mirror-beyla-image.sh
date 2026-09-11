#!/usr/bin/env bash
# Day 51 helper: mirror grafana/beyla:2.0.4 into Harbor library/
set -euo pipefail

SRC="${BEYLA_SRC_IMAGE:-grafana/beyla:2.0.4}"
DST="${BEYLA_DST_IMAGE:-harbor-server.jianggan.cn/library/beyla:2.0.4}"

echo "== pull $SRC =="
docker pull "$SRC"
echo "== tag → $DST =="
docker tag "$SRC" "$DST"
echo "== push $DST =="
docker push "$DST"
echo "OK: $DST"
