# Day 127–133 · 第 19 周索引（MCP 工具调用）

桌面：`专用测试环境/40_第19周复盘_MCP工具调用.md`  
安全边界：[day69-security-boundaries.md](day69-security-boundaries.md)

## Day 映射

| Day | 交付 | 状态 |
|-----|------|------|
| 127 | MCP 角色：只读运维副驾 | ✅ |
| 128 | 工具：observe logs/alerts | ✅ 契约对齐 day47/59/60 |
| 129 | 工具：resources/backups（只读，day100/117） | ✅ 文档 |
| 130 | 工具：kb_search（RAG） | ✅ |
| 131 | 工具：release/rollout **状态只读** | ✅ |
| 132 | 拒绝清单：apply/delete/scale/restore | ✅ |
| 133 | 审计字段：actor/tool/args/result | ✅ |

## 建议工具表

| Tool | 权限 | 说明 |
|------|------|------|
| `observe_logs` | 读 | 封装 LogsQL |
| `observe_alerts` | 读 | 列表/详情 |
| `observe_resources` | 读 | day100 |
| `kb_search` | 读 | day120+ |
| `release_status` | 读 | Argo/Rollout 状态摘要 |
| `remediate_*` | **默认禁用** | Week 21+ 且审批后 |

## 原则

- 无密钥回传；错误信息脱敏  
- 写操作 → 生成「待审批变更单」，不直接执行  

## 相关

- [day134-140-week20-diagnosis-agent.md](day134-140-week20-diagnosis-agent.md)
