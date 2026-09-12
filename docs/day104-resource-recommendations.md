# Day 104 · 资源建议报告模板（FinOps）

用途：基于 day99 画像输出「建议」而非自动变更。

## 报告头

| 项 | 填写 |
|----|------|
| 服务 / ns | |
| 周期 | |
| 数据来源 | kubectl top / Prometheus / 人工 |
| 是否含 sidecar | 是/否（day97） |

## 建议表

| 工作负载 | 现状 request | 观测用量 P95 | 建议 request | 建议 limit | 理由 | 风险 |
|----------|--------------|--------------|--------------|------------|------|------|
| | | | | | | |

## 弹性栏

- HPA：是否建议启用（min/max/指标）— 默认先写计划，apply 需确认（day101）  
- KEDA/VPA：仅引用 ADR-008，本阶段不推荐安装  

## 结论（三选一）

- [ ] 维持现状  
- [ ] 下调 request（省资源）  
- [ ] 上调 request / 开 HPA（保稳定）

变更落地：GitOps PR + 审批；**禁止** Agent/MCP 直接改资源。

## 相关

- [day100-resource-api.md](day100-resource-api.md)  
- [day90-release-risk-and-retro-templates.md](day90-release-risk-and-retro-templates.md)
