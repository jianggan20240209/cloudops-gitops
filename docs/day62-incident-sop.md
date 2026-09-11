# Day 62 · 故障定位 SOP（摘要）

完整：桌面 `专用测试环境/23_故障定位SOP.md`

流程：告警 → 分级确认 → 指标 → 日志/trace_id →（网络）Hubble → 变更/发布 → 恢复 → 复盘。

入口：CloudOps 告警列表/详情；Grafana；Alertmanager；Hubble `https://192.168.1.200:12000`。
