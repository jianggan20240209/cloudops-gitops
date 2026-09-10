# Day 50 · Tempo + OTel Collector

完整部署说明：桌面 `专用测试环境/11_Tempo_OTel_Collector部署.md`

## 管道

```text
Beyla / SDK ──OTLP──► otel-collector ──► Tempo
日志仍：Alloy → VictoriaLogs（ADR-002）
```

## 部署（确认后）

```bash
# 1) 镜像进 Harbor（若尚未）
# 2)
cd ~/code/cloudops-gitops && git pull
bash scripts/day50-deploy-tempo-otel.sh
```

清单：`dev/platform/observability/tracing/`
