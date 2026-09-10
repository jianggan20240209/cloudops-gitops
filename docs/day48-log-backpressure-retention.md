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

## 只读验收

```bash
kubectl -n logging get pvc
curl -sk 'https://cloudops.jianggan.cn/api/v1/observe/logs?namespace=cloudops-dev&trace_id=day46-trace-001&limit=3'
```

## 运行态变更（需确认）

Alloy ConfigMap 增加 probe `stage.drop` 后 `rollout restart ds/alloy`。  
详见桌面 `09` §7。
