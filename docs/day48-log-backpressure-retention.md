# Day 48 · 日志反压、采样与保留

训练正文（完整策略）：桌面文档  
`专用测试环境/09_日志反压采样与保留策略.md`

## lab 摘要

| 项 | 策略 |
|----|------|
| 保留 | VictoriaLogs **30d**，PVC **80Gi**；>70% 告警、>85% 紧急 |
| 高基数 | **禁止** `trace_id`/`request_id` 作流标签；作字段/全文 |
| 降噪 | Alloy drop `/healthz` `/readyz` `/metrics`；debug 可采样 |
| 反压 | 先降噪再扩容；Alloy/VL 设 limits；P0/P1 不主动丢 |
| 采集命名 | Alloy 组件名仍为 `loki.*`（Loki **兼容推送协议**）；后端是 **VictoriaLogs**，未部署 Loki |

## 验收记录（2026-09-10）

- [x] PVC `80Gi` Bound；observe 按 `day46-trace-001` 仍可查
- [x] `alloy-config` 已含 `stage.drop`（probe/metrics）；滚动后最新 `/readyz` 停在改造前 `12:42`，无持续新增
- [x] 已删除 `stage.labels` 中的 `trace_id`/`request_id`；仅保留 `namespace/pod/container/cluster`
- [x] Alloy DS 10/10 Ready

脚本：`scripts/day48-alloy-probe-drop.sh`
