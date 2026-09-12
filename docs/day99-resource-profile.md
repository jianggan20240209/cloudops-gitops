# Day 99 · 资源画像（Resource Profile）

桌面复盘：`专用测试环境/36_第15周复盘_资源治理与FinOps.md`

## 目标

统一「服务资源画像」字段，供 FinOps 建议与后续 Resource API（day100）使用。

## 字段（最小集）

| 字段 | 说明 |
|------|------|
| `service` / `namespace` / `workload` | 定位 |
| `replicas` | 期望/就绪副本 |
| `requests.cpu/memory` | 调度保证 |
| `limits.cpu/memory` | 上限；与 QoS 相关（day103） |
| `qosClass` | Guaranteed / Burstable / BestEffort |
| `hpa` | 是否配置、min/max、指标（默认可能未启用） |
| `sidecar` | 是否含 istio-proxy；成本见 [day97](day97-sidecar-cost-report-template.md) |
| `pdb` / `priorityClass` | 是否配置（day103） |
| `sampledAt` | 采集时间 |

## 采集口径（文档级）

```bash
kubectl -n <ns> get deploy,sts,rollout -o wide
kubectl -n <ns> get hpa,pdb,priorityclass
kubectl -n <ns> top pod --containers   # 可选；需 metrics-server
```

Prometheus（可选）：`container_cpu_usage_seconds_total`、`container_memory_working_set_bytes`。

## 非目标

- 本 Day **不**自动改 request/limit  
- **不**对生产主路径开启 HPA 压测（见 deferred）

## 相关

- [day100-resource-api.md](day100-resource-api.md)  
- [day104-resource-recommendations.md](day104-resource-recommendations.md)
