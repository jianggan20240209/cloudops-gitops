# Day 148–154 · 第 22 周索引（半自动自愈）

桌面：`专用测试环境/43_第22周复盘_半自动自愈.md`

## Day 映射

| Day | 交付 | 状态 |
|-----|------|------|
| 148 | 闭环状态机 | ✅ |
| 149 | 审批人与审计 | ✅ |
| 150 | 与 observe/告警联动 | ✅ |
| 151 | 与 RAG/MCP 联动 | ✅ |
| 152 | 演练清单（半自动） | ✅ 文档 |
| 153 | 失败回滚与复盘（day90） | ✅ |
| 154 | 全自动/破坏性 drill **延期** | ✅ deferred |

## 状态机

```text
Detected → Diagnosed → PendingApproval → Remediating → Verified → Retro
                ↘ Rejected / Expired
```

## 半自动演练（确认后）

1. 在隔离 ns 触发 day61 类故障  
2. Agent 产出诊断（只读工具）  
3. 人工批准 RemediationRequest  
4. Operator dry-run 或受控执行白名单动作  
5. 验证恢复 → 填 day90 复盘  

## 明确延期

见 [deferred-week15-22-runtime-followups.md](deferred-week15-22-runtime-followups.md)：无审批执行、full-loop destructive drill 等。
