# Day 59 · CloudOps 接入 Alertmanager 列表

- API：`GET /api/v1/observe/alerts?severity=P1&filter=`
- 实现：`cloudops-platform/services/cloudops-observe/alerts.go`
- 环境：`ALERTMANAGER_URL`（values 已开）
- UI：`cloudops-web` 告警列表面板

```bash
curl -sk 'https://cloudops.jianggan.cn/api/v1/observe/alerts'
curl -sk 'https://cloudops.jianggan.cn/api/v1/observe/alerts?severity=P1'
```

发版：Jenkins `test-cloudops-observe-kaniko` + `test-cloudops-web-kaniko`（确认后）。
