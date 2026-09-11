# Day 52 · gateway/cicd 少量 OTel SDK

完整说明：桌面 `专用测试环境/13_OTel_SDK_gateway_cicd.md`

## 管道

```text
gateway/cicd SDK ──OTLP :4318──► otel-collector ──► Tempo
  Resource: service.version + deployment.id
日志：同一 Span 的 trace_id → Alloy → VictoriaLogs
其余服务：Beyla（Day 51）
```

## 代码 / GitOps

| 仓库 | 提交 |
|------|------|
| cloudops-platform | `8ada9c6` OTel SDK + semconv v1.26 |
| cloudops-gitops | `7b9e45f` Deploy/Rollout `otel.enabled` |

## 验收（2026-09-11）

- [x] `cloudops-gateway` Deploy：`main-25`，`otel_enabled`
- [x] `cloudops-gateway-rollout`：`main-25` + OTEL env，`api.cloudops.jianggan.cn` → `version=main-25`
- [x] `cloudops-cicd`：`main-53`，`otel_enabled`（`service.version=main-53`）
- [x] Resource 日志可见 `service.version` / `deployment.id` / `deployment.environment=dev`
- [ ] Grafana Tempo：打开 Span 确认 Resource 属性（Explore 人工点开即可）
- [ ] VictoriaLogs：同 `trace_id` 命中访问日志（可选交叉验证）

## 快速复查

```bash
curl -sk https://api.cloudops.jianggan.cn/api/v1/version
kubectl -n cloudops-dev logs -l app=cloudops-gateway-rollout --tail=5 | grep otel_enabled
kubectl -n cloudops-dev logs -l app=cloudops-cicd --tail=5 | grep otel_enabled
bash scripts/day52-verify-otel-sdk.sh
# Grafana Explore → Tempo → service.name = cloudops-gateway-rollout | cloudops-cicd
```
