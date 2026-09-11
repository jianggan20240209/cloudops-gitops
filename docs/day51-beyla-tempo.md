# Day 51 · Beyla → OTLP → Tempo + Grafana

完整部署说明：桌面 `专用测试环境/12_Beyla_OTLP_Tempo.md`

## 管道

```text
cloudops-dev HTTP ──eBPF──► Beyla ──OTLP :4318──► otel-collector ──► Tempo
Grafana Explore（Tempo datasource）按 trace_id 查询
日志仍：Alloy → VictoriaLogs（ADR-002）
```

## 验收（2026-09-11）

- [x] Harbor：`library/beyla:2.0.4`
- [x] `tracing`：DaemonSet `beyla` 10/10 Ready（`discovery.services` + `k8s_namespace: cloudops-dev`）
- [x] Tempo `/api/search` 可见 `cloudops-web` / `cloudops-gateway` / `cloudops-observe` 等 Trace
- [x] Grafana：ConfigMap `monitoring/grafana-tempo-datasource` 已创建（`grafana_datasource: "1"`）

## 部署

```bash
cd ~/code/cloudops-gitops
bash scripts/day51-run-all-on-harbor.sh
```

清单：`dev/platform/observability/tracing/beyla/`、`.../grafana/tempo-datasource.yaml`

## 备注

- Beyla **2.0.4** 配置键为 `discovery.services`（不是新版文档的 `discovery.instrument`）。
- Grafana 若 `rollout restart` 卡在 PVC Multi-Attach：先删 Pending 新 Pod，再删旧 Running Pod，让副本在 PVC 所在节点重建。
