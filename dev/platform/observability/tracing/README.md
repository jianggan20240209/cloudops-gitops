# Tracing stack (Day 50–51)

Namespace: `tracing`

| Component | Role |
|-----------|------|
| `tempo` | Trace storage/query (monolithic, PVC 20Gi, retention 48h) |
| `otel-collector` | OTLP receiver → batch → Tempo |
| `beyla` | eBPF auto-instrument `cloudops-dev` → OTLP → Collector (Day 51) |

Endpoints (in-cluster):

```text
otel-collector.tracing.svc.cluster.local:4317  # OTLP gRPC
otel-collector.tracing.svc.cluster.local:4318  # OTLP HTTP
tempo.tracing.svc.cluster.local:3200           # Tempo HTTP API
```

Grafana: ConfigMap `monitoring/grafana-tempo-datasource` (sidecar).

Docs:

- desktop `专用测试环境/11_Tempo_OTel_Collector部署.md` (Day 50)
- desktop `专用测试环境/12_Beyla_OTLP_Tempo.md` (Day 51)
- `docs/day50-tempo-otel-collector.md` / `docs/day51-beyla-tempo.md`

Deploy:

```bash
bash scripts/day50-deploy-tempo-otel.sh
bash scripts/day51-mirror-beyla-image.sh   # once
bash scripts/day51-deploy-beyla.sh
```
