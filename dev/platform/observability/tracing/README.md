# Tracing stack (Day 50)

Namespace: `tracing`

| Component | Role |
|-----------|------|
| `tempo` | Trace storage/query (monolithic, PVC 20Gi, retention 48h) |
| `otel-collector` | OTLP receiver → batch → Tempo |

Endpoints (in-cluster):

```text
otel-collector.tracing.svc.cluster.local:4317  # OTLP gRPC
otel-collector.tracing.svc.cluster.local:4318  # OTLP HTTP
tempo.tracing.svc.cluster.local:3200           # Tempo HTTP API
```

Docs: desktop `专用测试环境/11_Tempo_OTel_Collector部署.md`

Deploy:

```bash
bash scripts/day50-deploy-tempo-otel.sh
```
