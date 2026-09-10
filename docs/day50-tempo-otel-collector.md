# Day 50 · Tempo + OTel Collector

完整部署说明：桌面 `专用测试环境/11_Tempo_OTel_Collector部署.md`

## 管道

```text
Beyla / SDK ──OTLP──► otel-collector ──► Tempo
日志仍：Alloy → VictoriaLogs（ADR-002）
```

## 验收（2026-09-10）

- [x] `tracing`：Tempo 1/1 Running（PVC 20Gi）
- [x] `otel-collector` 1/1 Running（config 使用 `debug`，勿用已废弃的 `logging`）
- [x] OTLP：`:4317` gRPC / `:4318` HTTP；健康检查 `:13133`

## 部署

```bash
cd ~/code/cloudops-gitops && git pull
bash scripts/day50-deploy-tempo-otel.sh
```

清单：`dev/platform/observability/tracing/`
