# Day 51 · Beyla → OTLP → Tempo + Grafana

完整部署说明：桌面 `专用测试环境/12_Beyla_OTLP_Tempo.md`

## 管道

```text
cloudops-dev HTTP ──eBPF──► Beyla ──OTLP :4318──► otel-collector ──► Tempo
Grafana Explore（Tempo datasource）按 trace_id 查询
日志仍：Alloy → VictoriaLogs（ADR-002）
```

## 验收

- [ ] Harbor：`library/beyla:2.0.4`
- [ ] `tracing`：DaemonSet `beyla` Ready
- [ ] Grafana：Tempo datasource 可见
- [ ] 造流后 Tempo / Grafana 至少 1 条 `cloudops-dev` Trace

## 部署

```bash
# harbor-server 一键（镜像 + 部署 + 造流探测）
cd ~/code/cloudops-gitops
# git pull 若 github:22 不通：用 Samba 同步到含 5aa4b86 后再执行
bash scripts/day51-run-all-on-harbor.sh
```

清单：`dev/platform/observability/tracing/beyla/`、`.../grafana/tempo-datasource.yaml`
