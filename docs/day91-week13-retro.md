# Day 91 · 第 13 周复盘摘要

完整：桌面 `专用测试环境/34_第13周复盘_灰度发布与回滚.md`  
ADR：桌面 `架构决策/ADR-007-Argo-Rollouts-vs-Flagger.md`  
索引：[day85-91-week13-rollouts.md](day85-91-week13-rollouts.md)

## 结论

主选 Argo Rollouts；demo 与 `cloudops-gateway-rollout` 并行路径已具备 Canary + Analysis；CloudOps 以只读 API 展示灰度状态。生产主路径 live pause/abort 与真 E-W 切流延期。

## Day 对照

| Day | 交付 | 状态 |
|-----|------|------|
| 85 | ADR-007 | ✅ |
| 86–87 | Canary + Analysis | ✅ |
| 88–89 | 状态页/失败关联（读与字段） | ✅ |
| 90 | 风险与复盘模板 | ✅ |
| 91 | 周复盘 | ✅ |

## 演示指针（录像前自检）

1. [argo-rollouts-1.9.0.md](argo-rollouts-1.9.0.md) — `rollouts-demo`  
2. [istio-argo-rollouts.md](istio-argo-rollouts.md) — 精确权重  
3. Dashboard：`https://rollouts.jianggan.cn`

## 延期

[deferred-week12-14-runtime-followups.md](deferred-week12-14-runtime-followups.md)
