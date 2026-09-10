#!/usr/bin/env bash
# Day 48: Alloy — drop probe/metrics noise; do not promote trace_id to labels
#
# Usage (harbor-server):
#   cd ~/code/cloudops-gitops && git pull
#   cp scripts/day48-alloy-probe-drop.sh /root/tools/log-system/
#   bash /root/tools/log-system/day48-alloy-probe-drop.sh
#
# Fix note: ConfigMap key `config.alloy` contains a dot — do NOT use
# jsonpath `{.data['config.alloy']}` (often returns empty). Use go-template index.
set -euo pipefail

NS=logging
CM=alloy-config
KEY=config.alloy
TS=$(date +%Y%m%d%H%M%S)
BACKUP_DIR=/root/tools/log-system/backups
mkdir -p "$BACKUP_DIR" /root/tools/log-system

echo "== 0) check =="
kubectl -n "$NS" get cm "$CM"
kubectl -n "$NS" get ds -l app.kubernetes.io/name=alloy -o wide || true
echo "ConfigMap data keys:"
kubectl -n "$NS" get cm "$CM" -o go-template='{{range $k,$v := .data}}{{println $k}}{{end}}'

echo "== 1) backup ConfigMap =="
BACKUP_YAML="$BACKUP_DIR/alloy-config.${TS}.yaml"
kubectl -n "$NS" get cm "$CM" -o yaml >"$BACKUP_YAML"
echo "backup => $BACKUP_YAML"

LIVE=/tmp/config.alloy.live.${TS}
PATCHED=/tmp/config.alloy.patched.${TS}

# Robust extract (key has a dot)
kubectl -n "$NS" get cm "$CM" -o go-template="{{index .data \"${KEY}\"}}" >"$LIVE"

# Fallback: parse backup YAML with python if still empty
if [[ ! -s "$LIVE" ]]; then
  echo "WARN: go-template empty; extracting from backup yaml via python"
  python3 - "$BACKUP_YAML" "$LIVE" "$KEY" <<'PY'
import sys
from pathlib import Path
backup, out, key = sys.argv[1], sys.argv[2], sys.argv[3]
text = Path(backup).read_text(encoding="utf-8")
# Minimal YAML-ish extract for data.<key>: | block
marker = f"  {key}: |"
idx = text.find(marker)
if idx < 0:
    # try quoted key forms
    for m in (f'  "{key}": |', f"  '{key}': |"):
        idx = text.find(m)
        if idx >= 0:
            marker = m
            break
if idx < 0:
    raise SystemExit(f"cannot find {key} in backup yaml")
start = text.find("\n", idx) + 1
lines = []
for line in text[start:].splitlines(True):
    if line.startswith("    ") or line == "\n" or line.strip() == "":
        # indented content under |  (4 spaces) — keep stripping 4 spaces
        if line.startswith("    "):
            lines.append(line[4:])
        elif line.strip() == "":
            lines.append("\n" if line.endswith("\n") else "")
        else:
            break
    elif line.startswith("  ") and not line.startswith("    "):
        break
    else:
        break
Path(out).write_text("".join(lines), encoding="utf-8")
print("extracted bytes", Path(out).stat().st_size)
PY
fi

echo "live bytes: $(wc -c <"$LIVE")  lines: $(wc -l <"$LIVE")"
if [[ ! -s "$LIVE" ]]; then
  echo "ERROR: still empty config; inspect:"
  echo "  kubectl -n $NS get cm $CM -o yaml | head -80"
  exit 1
fi

grep -nE 'loki\.(process|source|write|relabel)|local\.file_match|discovery\.|stage\.' "$LIVE" | head -60 || true

echo "== 2) patch with python =="
python3 - "$LIVE" "$PATCHED" <<'PY'
import re, sys
src, dst = sys.argv[1], sys.argv[2]
text = open(src, encoding="utf-8").read()
if not text.strip():
    raise SystemExit("ERROR: empty live config")

# Remove high-cardinality label promotion for trace_id / request_id
text2, n = re.subn(
    r"\n[ \t]*stage\.labels\s*\{(?:[^{}]|\n)*?(?:trace_id|request_id)(?:[^{}]|\n)*?\}\s*",
    "\n",
    text,
)
print(f"removed stage.labels blocks: {n}")

drop = r'''
      // Day48: drop kube probe / metrics access noise
      stage.drop {
        expression          = ".*(path=/healthz|path=/readyz|path=/metrics|/api/healthz|/api/readyz|\"path\":\"/healthz\"|\"path\":\"/readyz\"|\"path\":\"/metrics\").*"
        drop_counter_reason = "probe_or_metrics_path"
      }
'''

if "probe_or_metrics_path" in text2:
    print("drop rule already present")
else:
    patterns = [
        r'loki\.process\s+"extract"\s*\{[ \t]*\n(?:[ \t]*forward_to\s*=\s*\[[^\]]+\][ \t]*\n)?',
        r'loki\.process\s+"[^"]+"\s*\{[ \t]*\n(?:[ \t]*forward_to\s*=\s*\[[^\]]+\][ \t]*\n)?',
        r'loki\.process\s+"[^"]+"\s*\{[ \t]*\n',
    ]
    m = None
    for p in patterns:
        m = re.search(p, text2)
        if m:
            break
    if not m:
        # Show hints for operators
        names = re.findall(r'loki\.process\s+"([^"]+)"', text2)
        comps = re.findall(r'^(?:local|loki|discovery|prometheus)\.[\w.]+\s+"[^"]+"', text2, flags=re.M)
        print("HINT process names:", names)
        print("HINT components sample:", comps[:20])
        raise SystemExit('ERROR: cannot find loki.process insertion point; abort')
    text2 = text2[: m.end()] + drop + text2[m.end() :]
    print("inserted stage.drop after:", m.group(0).splitlines()[0])

open(dst, "w", encoding="utf-8", newline="\n").write(text2)
print("patched =>", dst)
PY

echo "== 3) diff =="
diff -u "$LIVE" "$PATCHED" || true

echo "== 4) apply ConfigMap =="
kubectl -n "$NS" create configmap "$CM" \
  --from-file="${KEY}=${PATCHED}" \
  -o yaml --dry-run=client | kubectl apply -f -

cp -a "$PATCHED" "/root/tools/log-system/config.alloy.day48.${TS}"
cp -a "$PATCHED" /root/tools/log-system/config.alloy.current

echo "== 5) restart DaemonSet =="
kubectl -n "$NS" rollout restart ds/alloy
kubectl -n "$NS" rollout status ds/alloy --timeout=300s
kubectl -n "$NS" get po -l app.kubernetes.io/name=alloy -o wide

POD=$(kubectl -n "$NS" get po -l app.kubernetes.io/name=alloy -o jsonpath='{.items[0].metadata.name}')
echo "== 6) alloy logs (tail) =="
kubectl -n "$NS" logs "$POD" --tail=40

cat <<EOF

Done. Backup: $BACKUP_YAML

Wait 2-3 minutes, then verify:

VL_IP=\$(kubectl -n logging get po vls-victoria-logs-single-server-0 -o jsonpath='{.status.podIP}')
HOST_IP=\$(kubectl -n logging get po vls-victoria-logs-single-server-0 -o jsonpath='{.status.hostIP}')
ssh root@\$HOST_IP "curl -sS -G 'http://\${VL_IP}:9428/select/logsql/query' \\
  --data-urlencode 'query=namespace:cloudops-dev path=/readyz' \\
  --data-urlencode 'limit=5'"

curl -sk 'https://cloudops.jianggan.cn/api/v1/observe/logs?namespace=cloudops-dev&container=cloudops-gateway&trace_id=day46-trace-001&limit=3'

Rollback:
  kubectl apply -f $BACKUP_YAML
  kubectl -n logging rollout restart ds/alloy
EOF
