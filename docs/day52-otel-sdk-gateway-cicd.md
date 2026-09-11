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

## 验收

- [ ] Jenkins 出新 `main-<N>` 镜像并滚动
- [ ] Pod env 含 `OTEL_EXPORTER_OTLP_ENDPOINT` / `DEPLOYMENT_ID`
- [ ] 日志出现 `otel_enabled`
- [ ] Tempo Span Resource 含 `service.version`、`deployment.id`
- [ ] VictoriaLogs 同 `trace_id` 命中
- [ ] `/metrics` 仍有 version 标签
