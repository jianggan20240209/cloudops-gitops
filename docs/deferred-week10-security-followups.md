# 延期项 · 第 10 周安全落地（集群建完后再做）

状态：**延期 / Deferred**  
记录日：2026-09-12  
原则：避免 lab 发布与节点负载误伤；等实验集群与发布链路完全稳定后再执行。

## 延期清单

| # | 项 | 现状 | 建议时机 | 入口 |
|---|-----|------|----------|------|
| 1 | **Falco Helm 安装** | 仅有 `values-lab.yaml` + 规则 + `scripts/day68-falco-plan.sh`；**未安装** | 集群建设完成、节点资源有余量后；`CONFIRM=1` 再装 | `docs/day68-falco-runtime.md` |
| 2 | **Kyverno 安装 + 强制阻断 `:latest`** | 仅有 Audit 草案 `admission/kyverno-block-latest.yaml`；**未装 Kyverno、未 Enforce** | 发布准入演练周；先 Audit 观察 ≥1 周再 `Enforce` | `docs/day67-harbor-scan-admission.md` |
| 3 | **Harbor UI「自动扫描」开关** | 规范已写；需在 Harbor 项目上手动开启 Trivy 自动扫描 | 制品治理 / 第 11 周前后；项目 `cloudops`、`library` | Harbor UI → Project → Configuration → Vulnerability scanning |

## 明确不做（当前）

- 不对 `cloudops-dev` 业务 ns 直接 default-deny（已用隔离 ns `cloudops-seclab` 演练）
- 不把 `cloudops-admin` ClusterRole 绑到真人（示例 binding subjects 为空）
- 不在未确认时跑 `CONFIRM=1 bash scripts/day68-falco-plan.sh`

## 恢复时检查单

- [ ] 节点 CPU/内存余量足够跑 Falco DS（modern_ebpf）
- [ ] Harbor 已能稳定推拉；再开自动扫描与（可选）防高危
- [ ] Kyverno：先 `validationFailureAction: Audit`，确认无误伤再建站 Enforce
- [ ] 更新 ADR-005 验证勾选与第 10 周复盘

## 相关提交

- Week10 清单：`370fbf3`（`dev/platform/security/`）
- ADR：桌面 `架构决策/ADR-005-CloudOps云原生安全治理.md`
