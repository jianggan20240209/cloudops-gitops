# Day 97 · Sidecar 成本报告模板

用途：注入前后对比 CPU/内存；**先在 demo ns 测量**，勿对基础设施强制注入。

## 测量命令（示例）

```bash
# 注入前：记录业务容器
kubectl -n <ns> top pod -l app=<app>

# 注入后：注意 istio-proxy 容器
kubectl -n <ns> get pod -l app=<app> -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .spec.containers[*]}{.name}{" "}{end}{"\n"}{end}'
kubectl -n <ns> top pod -l app=<app> --containers
```

可选：Prometheus `container_cpu_usage_seconds_total` / `container_memory_working_set_bytes`，按 `pod`+`container` 过滤 `istio-proxy`。

## 报告表（复制填写）

| 项 | 注入前 | 注入后 | 差值 |
|----|--------|--------|------|
| 副本数 | | | |
| 业务容器 CPU（平均） | | | |
| 业务容器 Memory | | | |
| istio-proxy CPU | — | | |
| istio-proxy Memory | — | | |
| Pod 总 Memory | | | |
| 每千 QPS 额外开销（估） | | | |

## 结论栏

```text
服务：
命名空间：
是否建议长期注入：是 / 否 / 仅灰度窗口
理由（排障复杂度 / 资源 / E-W 需求）：
```

## 相关现状

- N-S 演示路径大量依赖 **ingressgateway** 指标，业务 Pod **未必**已注入——成本报告应标明「gateway 成本 vs sidecar 成本」。  
- STRICT mTLS、全 NS 强制注入：**延期** → [deferred-week12-14-runtime-followups.md](deferred-week12-14-runtime-followups.md)  
- Header 灰度：[cloudops-gateway-header-tenant-canary.md](cloudops-gateway-header-tenant-canary.md)
