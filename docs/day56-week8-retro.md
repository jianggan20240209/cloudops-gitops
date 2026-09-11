# Day 56 · 第 8 周复盘摘要

完整正文：桌面  
`专用测试环境/17_第8周复盘_OTel_Tempo_Hubble.md`

## 结论

- 闭环：Beyla + 少量 SDK → Collector → Tempo；Hubble 网络补充；CloudOps 观测跳转  
- ADR-003 验证项全部 ✅  
- 关联：日志 `trace_id` ↔ Tempo；网络决策树：Endpoints → DNS → 策略(Hubble) → Trace  

## 速查

```bash
curl -sk https://cloudops.jianggan.cn/ | grep -E 'Day 55|192.168.1.200:12000'
kubectl -n tracing get deploy,po
kubectl -n kube-system port-forward --address 0.0.0.0 svc/hubble-ui 12000:80
# https://grafana.jianggan.cn → Explore → Tempo
```
