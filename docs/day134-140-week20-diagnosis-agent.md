# Day 134–140 · 第 20 周索引（智能诊断 Agent）

桌面：`专用测试环境/41_第20周复盘_智能诊断Agent.md`

## Day 映射

| Day | 交付 | 状态 |
|-----|------|------|
| 134 | Agent 输入：告警 fingerprint + ns | ✅ |
| 135 | 取证：MCP observe + kb_search | ✅ |
| 136 | 案例：OOM/5xx（day61） | ✅ 剧本映射 |
| 137 | 案例：网络（day54） | ✅ |
| 138 | 案例：发布/回滚（day90） | ✅ |
| 139 | 输出模板：假设/证据/建议动作 | ✅ |
| 140 | 边界：不自动执行（day69） | ✅ |

## 输出模板

```markdown
## 诊断摘要
- 告警：
- 影响面：

## 证据
- 指标/日志/trace/Hubble 链接或查询：

## 假设（按置信度）
1.

## 建议动作（待审批）
- [ ] ...
- 回滚/验证步骤：
```

## 相关

- [day62-incident-sop.md](day62-incident-sop.md)  
- [day141-147-week21-operator.md](day141-147-week21-operator.md)
