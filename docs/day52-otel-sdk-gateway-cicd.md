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
| cloudops-platform | `f7e2dc6` feat(otel): gateway + cicd SDK |
| cloudops-gitops | `ec25327` Helm `otel.enabled` + verify script |

## 构建部署（harbor / Jenkins UI）

```bash
# Jenkins 任务（构建并自动 patch Argo imageTag）：
#   test-cloudops-gateway-kaniko
#   test-cloudops-cicd-kaniko
# 先确保 Argo 已同步 gitops（otel env），再跑上述两个 Job

cd ~/code/cloudops-gitops && git pull
# 若 Argo 未自动同步：
# argocd app sync cloudops-gateway-dev cloudops-cicd-dev
# 或 kubectl -n argocd patch ...

# Job 成功、Pod 滚动后：
bash scripts/day52-verify-otel-sdk.sh
```

## 验收（2026-09-11）

- [x] Jenkins：`cloudops-gateway:main-25`（`8ada9c6`）已滚动；`otel_enabled` 含 `service.version` / `deployment.id`
- [ ] `cloudops-cicd` 新镜像 + `otel_enabled`（确认 `main-53` 或当前 BUILD）
- [ ] Rollout `cloudops-gateway-rollout` 已切到 `main-25`（`api.cloudops.jianggan.cn`）
- [ ] Tempo Span Resource 可见 `service.version`、`deployment.id`
- [ ] VictoriaLogs 同 `trace_id` 命中
- [x] `/metrics` 仍有 version 标签（既有行为）
