# Day 49 · 第 7 周复盘摘要

完整正文（含 SOP）：桌面  
`专用测试环境/10_第7周复盘_VictoriaLogs_Alloy_trace_id.md`

## 结论

- 闭环：Alloy → VictoriaLogs → observe/LogsQL，按 `trace_id` 排障  
- ADR-002 验证项全部 ✅  
- `loki.*` = 兼容推送协议；存储是 VictoriaLogs，**未部署 Loki**

## 速查

```bash
curl -sk 'https://cloudops.jianggan.cn/api/v1/observe/logs?namespace=cloudops-dev&trace_id=day46-trace-001&limit=5'
kubectl -n logging get ds alloy
kubectl -n logging get pvc
```
