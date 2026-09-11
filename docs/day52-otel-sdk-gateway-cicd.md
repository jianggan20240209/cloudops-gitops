# Day 52 · gateway/cicd 少量 OTel SDK

完整说明：桌面 `专用测试环境/13_OTel_SDK_gateway_cicd.md`

## 管道

```text
gateway/cicd SDK ──OTLP :4318──► otel-collector ──► Tempo
  Resource: service.version + deployment.id
日志：同一 Span 的 trace_id → Alloy → VictoriaLogs
其余服务：Beyla（Day 51）
```

## 验收

- [ ] 新镜像含 OTel SDK（Jenkins 构建 gateway + cicd）
- [ ] Helm `otel.enabled: true`，Pod env 含 `OTEL_EXPORTER_OTLP_ENDPOINT` / `DEPLOYMENT_ID`
- [ ] Tempo Span Resource 可见 `service.version`、`deployment.id`
- [ ] VictoriaLogs 同 `trace_id` 命中 JSON 访问日志
- [ ] `/metrics` 仍含 version 标签

## 部署

```bash
# 1) 构建镜像（Jenkins）：cloudops-gateway / cloudops-cicd
# 2) bump imageTag 后 Argo 同步，或：
cd ~/code/cloudops-gitops && git pull
# 确认 values 中 otel.enabled 与 imageTag
```
