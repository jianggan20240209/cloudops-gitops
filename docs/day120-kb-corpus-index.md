# Day 120 · KB 语料索引

完整目录：[kb/README.md](kb/README.md)  
桌面复盘：`专用测试环境/39_第18周复盘_RAG知识库.md`  
选型：桌面 ADR-010

## 语料分层

| 层 | 内容 | 用途 |
|----|------|------|
| SOP | 故障定位、备份、演练 | Agent 诊断首检 |
| ADR | 001–011 | 选型与边界 |
| Day | 47+ observe / 54 / 61 / 62 / 69 / 90 / 97 / 99+ | 可操作入口 |
| Deferred | week10 / 12–14 / 15–22 | 禁止事项 |

## 关键链（核心）

- [day54-network-fault-labs.md](day54-network-fault-labs.md)  
- [day61-fault-drill-oom-500-redis.md](day61-fault-drill-oom-500-redis.md)  
- [day62-incident-sop.md](day62-incident-sop.md)  
- [day69-security-boundaries.md](day69-security-boundaries.md)  
- [day90-release-risk-and-retro-templates.md](day90-release-risk-and-retro-templates.md)  
- [day97-sidecar-cost-report-template.md](day97-sidecar-cost-report-template.md)  
- observe：day47 / day59 / day60  
- Longhorn：见 BC/Velero 文档中的存储前提（day114/118）

## 更新规则

新增 SOP/ADR 时同步改 `kb/README.md`；**禁止**把密码、Token 写入语料。
