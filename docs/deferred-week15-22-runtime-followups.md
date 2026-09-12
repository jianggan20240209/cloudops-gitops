# 延期项 · 第 15–22 周运行时 Follow-ups

状态：**延期 / Deferred**  
记录日：2026-09-12  
原则：下列项含破坏性、压测打满、恢复写 live、或无审批自动变更，**禁止**在未明确确认时执行。

关联：桌面复盘 `36`–`43`；索引 day99–154；ADR-008/009/010/011。

## 延期清单

| # | 项 | 现状 | 风险 | 建议时机 | 入口 |
|---|-----|------|------|----------|------|
| 1 | **Chaos Mesh live 安装与 Experiment** | 未装；用 day54/61 | 误伤业务/控制面 | 集群与发布链路稳定后 | ADR-009；day106–112 |
| 2 | **HPA load storm**（打满节点/主路径） | 仅有计划，manifest 默认 off | 驱逐风暴、雪崩 | 隔离 ns + 资源余量确认 | day101；ADR-008 |
| 3 | **Velero delete-restore 演练** | 仅安装计划 | 数据丢失/服务中断 | BC 窗口 + 备份校验通过 | day114；day118 |
| 4 | **etcd restore 到 live** | 仅备份 SOP | 全集群回滚/脑裂风险 | 灾难演练专用窗口 | day113 |
| 5 | **Operator execute 无审批** | 设计为强制审批 | 误杀/越权变更 | 误报率与审计达标后评估 | ADR-011；day141–147 |
| 6 | **full-loop 破坏性自愈 drill** | 半自动文档 | 叠加发布/网格故障面 | Week 22 能力就绪且单项演练通过 | day148–154 |

## 明确当前不做

- 不把 Chaos Mesh 当 Week 16 必装项  
- 不对 `cloudops.jianggan.cn` 主路径默认开 HPA 压测  
- 不在文档或 git 中存放对象存储/集群恢复密码  
- 不开放 MCP 默认写工具  

## 与其他 deferred 的边界

- 网格 STRICT mTLS / E-W 注入等：仍见 `deferred-week12-14-runtime-followups.md`  
- Falco/Kyverno 等：见 `deferred-week10-security-followups.md`

## 恢复时检查单

- [ ] 隔离 ns 演练通过且有 cleanup  
- [ ] 备份可校验；RTO/RPO 已书面确认  
- [ ] Remediation 白名单 + 审批 + 审计齐备  
- [ ] 更新对应桌面周复盘与 ADR 验证勾选  

## 相关 ADR

- ADR-008 HPA / KEDA  
- ADR-009 轻量注入 vs Chaos Mesh  
- ADR-010 RAG  
- ADR-011 Kubebuilder Operator
