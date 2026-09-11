# Day 85–91 · 第 13 周索引（Argo Rollouts 灰度）

桌面复盘：`专用测试环境/34_第13周复盘_灰度发布与回滚.md`  
选型 ADR：桌面 `架构决策/ADR-007-Argo-Rollouts-vs-Flagger.md`

## 既有资产

| 主题 | 文档 |
|------|------|
| Rollouts 1.9.0 安装与 demo | [argo-rollouts-1.9.0.md](argo-rollouts-1.9.0.md) |
| Istio 精确权重（与第 14 周交叉） | [istio-argo-rollouts.md](istio-argo-rollouts.md) |
| gateway 并行 Rollout | [cloudops-gateway-rollout.md](cloudops-gateway-rollout.md) |
| 流量策略 / 切流 | [cloudops-gateway-traffic-policy.md](cloudops-gateway-traffic-policy.md)、[cloudops-gateway-cutover-runbook.md](cloudops-gateway-cutover-runbook.md) |
| cicd 读接口 | [helm-argocd-cicd.md](helm-argocd-cicd.md)（`/rollout` `/analysisruns` `/traffic`） |
| 风险与复盘模板 | [day90-release-risk-and-retro-templates.md](day90-release-risk-and-retro-templates.md) |
| 周复盘 | [day91-week13-retro.md](day91-week13-retro.md) |

## Day 映射

| Day | 交付 | 状态 |
|-----|------|------|
| 85 | ADR-007 | ✅ |
| 86 | Canary YAML（demo / gateway-rollout） | ✅ |
| 87 | AnalysisTemplate + Abort 经验 | ✅ |
| 88 | CloudOps 灰度状态（读） | ✅ |
| 89 | 失败关联观测字段 | ✅ 设计层 |
| 90 | 风险评估 + 复盘模板 | ✅ |
| 91 | 周复盘 | ✅ |

## 延期

对生产主路径 live **pause/abort**、真 E-W sidecar 切流 → [deferred-week12-14-runtime-followups.md](deferred-week12-14-runtime-followups.md)
