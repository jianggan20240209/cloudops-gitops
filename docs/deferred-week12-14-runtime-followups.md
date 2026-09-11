# 延期项 · 第 12–14 周运行时 Follow-ups

状态：**延期 / Deferred**  
记录日：2026-09-12  
原则：等实验集群与发布主链路**完全稳定**后再做；下列项含破坏性、全量注入或生产路径写操作，**禁止**在未确认时执行。

关联复盘：桌面 `33`/`34`/`35`；索引 `day78-84` / `day85-91` / `day92-98`。

## 延期清单

| # | 项 | 现状 | 风险 | 建议时机 | 入口 |
|---|-----|------|------|----------|------|
| 1 | **STRICT mTLS**（PeerAuthentication） | 未对业务 ns 强制 | 断东西向明文依赖、排障面扩大 | 集群稳定 + 先 PERMISSIVE 观察 | ADR-004；day96 |
| 2 | **强制注入全部业务 NS** | 仅按需/演示路径 | 资源打满、滚动风暴 | 单 ns 白名单验证后再扩 | day97 成本模板 |
| 3 | **live Rollout pause/abort API 打生产主路径** | cicd **读**接口已有；写操作未对主入口开放 | 误 abort 中断服务 | 仅 demo/`cloudops-gateway-rollout` 演练通过后，再审批主路径 | helm-argocd-cicd.md；ADR-007 |
| 4 | **真 E-W sidecar 金丝雀切流** | N-S Gateway+VS ✅ | 需多服务注入与调用链改造 | demo 多语言三件套就绪后 | istio-argo-rollouts.md；ADR-004 |
| 5 | **Istio / Argo Rollouts wipe 重装** | GitOps 已装 | 中断所有灰度与网格 | 仅灾难恢复演练窗口 | istio / argo-rollouts 文档 |
| 6 | **混沌工程**（杀 istiod / 断网 / 故障注入） | 未做 | 连带可观测与发布 | 第 15+ 周稳定性阶段 | 训练计划后续周 |
| 7 | **默认网关路径启用 timeout/retry** | 并行 chart 有 trafficPolicy 参考；**主入口未默认强开** | 误伤长请求 / 重试风暴 | 独立域名验证充分后再切主路径 | cloudops-gateway-traffic-policy.md；cutover runbook |

## 明确当前不做

- 不把 Jenkins / Harbor / Argo CD / 监控 / 数据组件打进 mesh  
- 不在未 `CONFIRM` 时对 `cloudops.jianggan.cn` 主入口执行 cutover  
- 不与第 10 周安全延期混淆：Falco/Kyverno/Harbor 自动扫描仍见 `deferred-week10-security-followups.md`

## 恢复时检查单

- [ ] 节点资源足够承担 sidecar / STRICT mTLS  
- [ ] demo ns E-W 90/10、50/50 可重复演示  
- [ ] pause/abort 仅绑定受控 SA + 审批  
- [ ] timeout/retry 在并行域名压测通过  
- [ ] 更新 ADR-004 验证勾选与桌面第 14 周复盘

## 相关 ADR

- ADR-004 Istio 引入策略  
- ADR-006 Jenkins/Harbor/Argo 分工  
- ADR-007 Rollouts vs Flagger
