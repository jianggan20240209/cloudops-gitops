# Day 58 · 基础 Prometheus 告警规则

清单：`dev/platform/observability/alerting/week9-basic-rules.yaml`  
分级：`docs/day57-alert-severity-p0-p3.md`

覆盖：Node Ready/磁盘、Pod CrashLoop/OOM/重启、CoreDNS、CloudOps gateway、Day61 Redis。

```bash
kubectl apply -f dev/platform/observability/alerting/week9-basic-rules.yaml
kubectl -n monitoring get prometheusrule cloudops-week9-basic-alerts -o yaml | head
# Prometheus UI → Alerts 可见规则组 cloudops.*
```

说明：`CloudOpsGatewayHighErrorRate` 依赖 `http_requests_total{job="cloudops-gateway"}`；若实际指标名不同，按 scrape 标签改 expr。
