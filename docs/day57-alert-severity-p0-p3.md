# Day 57 · 告警分级 P0–P3

完整说明：桌面 `专用测试环境/18_告警分级P0-P3.md`

| 级别 | 含义 | 响应 | 示例 |
|------|------|------|------|
| P0 | 平台不可用 / 全域影响 | 立即 | CoreDNS Down、gateway 全挂 |
| P1 | 核心业务受损 | ≤15min | OOM、CrashLoop、5xx>5% |
| P2 | 降级 / 局部 | 工作时段 | 磁盘<15%、重启偏高、演练 Redis |
| P3 | 提示 / 趋势 | 工单 | Watchdog、容量预警 |

标签约定：`severity` / `priority` = `P0|P1|P2|P3`（PrometheusRule）。
