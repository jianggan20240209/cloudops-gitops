# Day 92–98 · 第 14 周索引（Istio 流量治理）

桌面复盘：`专用测试环境/35_第14周复盘_Istio流量治理.md`  
策略 ADR：桌面 `架构决策/ADR-004-Istio引入策略.md`

## 既有资产

| 主题 | 文档 |
|------|------|
| Istio + Rollouts 精确灰度 | [istio-argo-rollouts.md](istio-argo-rollouts.md) |
| gateway 并行 Rollout | [cloudops-gateway-rollout.md](cloudops-gateway-rollout.md) |
| Header / 租户金丝雀 | [cloudops-gateway-header-tenant-canary.md](cloudops-gateway-header-tenant-canary.md) |
| 流量策略 | [cloudops-gateway-traffic-policy.md](cloudops-gateway-traffic-policy.md) |
| 切流 runbook / dry-run | [cloudops-gateway-cutover-runbook.md](cloudops-gateway-cutover-runbook.md)、[cloudops-gateway-cutover-dry-run.md](cloudops-gateway-cutover-dry-run.md) |
| mesh 边界清单 | [day96-mesh-boundary-inventory.md](day96-mesh-boundary-inventory.md) |
| sidecar 成本模板 | [day97-sidecar-cost-report-template.md](day97-sidecar-cost-report-template.md) |
| 周复盘 | [day98-week14-retro.md](day98-week14-retro.md) |

## Day 映射

| Day | 交付 | 状态 |
|-----|------|------|
| 92 | N-S/E-W 边界笔记 | ✅ |
| 93 | Istio GitOps 安装；基础设施不注入 | ✅ |
| 94 | Gateway / VS 与 Ingress 边界 | ✅ |
| 95 | Rollouts 权重演示 | ✅ **N-S**；E-W ⏳ |
| 96 | 进/不进 mesh 清单 | ✅；默认路径 timeout/retry 开启 ⏳ |
| 97 | Header 灰度 + 成本模板 | ✅ 部分；STRICT mTLS ⏳ |
| 98 | 复盘 + ADR-004 核对 | ✅ |

## 延期总表

[deferred-week12-14-runtime-followups.md](deferred-week12-14-runtime-followups.md)
