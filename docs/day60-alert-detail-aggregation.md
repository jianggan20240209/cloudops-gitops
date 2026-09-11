# Day 60 · 告警详情聚合

- API：`GET /api/v1/observe/alerts/detail?fingerprint=&alertname=&namespace=&pod=`
- 聚合：alert + Prometheus query + VictoriaLogs 片段 + runbook + 外链
- Events：占位（后续接 k8s client）；先用 `kubectl get events` 人工补

```bash
curl -sk 'https://cloudops.jianggan.cn/api/v1/observe/alerts/detail?alertname=KubePodCrashLooping&namespace=cloudops-dev'
```
