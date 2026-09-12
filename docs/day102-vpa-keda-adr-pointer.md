# Day 102 · VPA / KEDA ADR 指针

完整决策：桌面 `架构决策/ADR-008-VPA-vs-KEDA选型.md`

## 摘要

| 项 | Lab 结论 |
|----|----------|
| 默认弹性 | **HPA**（[day101](day101-hpa-drill-plan.md)，manifest 默认 off） |
| VPA | 暂不安装；避免与 HPA 冲突 |
| KEDA | **后续候选**（有明确事件源再 POC） |

## 何时重开 ADR

- 出现稳定队列/Cron/外部指标需求  
- 或 request 漂移严重需 VPA recommender（仍建议与 HPA 分对象）

## 相关

- [day99-resource-profile.md](day99-resource-profile.md)  
- [day105-week15-retro.md](day105-week15-retro.md)
