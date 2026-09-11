# Day 63 · 第 9 周复盘摘要

完整：桌面 `专用测试环境/24_第9周复盘_告警与SOP.md`

## 结论

- P0–P3 分级落地；基础 PrometheusRule 入库  
- observe 接 Alertmanager 列表 + 详情聚合  
- 三演练：OOM / 5xx / Redis 断连 + SOP  

## 三案例（模板）

1. Pod OOM → 调 limits / 查泄漏  
2. Gateway 5xx → 日志 + Tempo + 回滚  
3. Redis 断连（演练）→ 恢复副本 + 依赖降级设计  
