# Day 106–112 · 第 16 周索引（混沌与稳定性）

桌面复盘：`专用测试环境/37_第16周复盘_混沌与稳定性.md`  
策略 ADR：桌面 `架构决策/ADR-009-轻量故障注入优于ChaosMesh初装.md`

## 既有资产（优先复用）

| 主题 | 文档 |
|------|------|
| 网络故障三实验 | [day54-network-fault-labs.md](day54-network-fault-labs.md) |
| OOM / 5xx / Redis | [day61-fault-drill-oom-500-redis.md](day61-fault-drill-oom-500-redis.md) |
| 故障定位 SOP | [day62-incident-sop.md](day62-incident-sop.md) |
| 发布风险/复盘模板 | [day90-release-risk-and-retro-templates.md](day90-release-risk-and-retro-templates.md) |
| 稳定性系统设计 | [day111-stability-system-design.md](day111-stability-system-design.md) |
| 周复盘 | [day112-week16-retro.md](day112-week16-retro.md) |

## Day 映射

| Day | 交付 | 状态 |
|-----|------|------|
| 106 | 场景清单 ↔ day54/61 映射 | ✅ |
| 107 | 网络类复盘（DNS/SVC/NetPol） | ✅ 文档（执行需确认） |
| 108 | 应用类复盘（OOM/5xx/依赖） | ✅ 文档 |
| 109 | 轻量故障注入原则 | ✅ ADR-009 |
| 110 | Chaos Mesh **延期**说明 | ✅ deferred |
| 111 | 稳定性系统设计 | ✅ |
| 112 | 周复盘 | ✅ |

## 场景映射表

| 稳定性目标 | 既有剧本 | 观测 |
|------------|----------|------|
| 东西向/DNS/策略 drop | day54 | Hubble、日志 |
| 资源耗尽 / 依赖故障 | day61 | 告警、observe alerts |
| 定位闭环 | day62 | Grafana / VL / Tempo |
| 变更相关故障 | day90 模板 | Argo / Rollouts |

## Chaos Mesh

**初装延期**。恢复条件见 [deferred-week15-22-runtime-followups.md](deferred-week15-22-runtime-followups.md)。
