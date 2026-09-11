# Day 96 · Mesh 接入边界清单（Inventory）

对齐 ADR-004：业务按需进 mesh；基础设施默认不进。

## 进入 Mesh（候选 / 按需）

| 工作负载 | 方向重点 | 现状（2026-09） |
|----------|----------|-----------------|
| `rollouts-demo-istio` | N-S Gateway + VS 权重 | ✅ 演示路径 |
| `cloudops-gateway-rollout` | N-S 并行域名 / API 域名 | ✅ 并行，非替换主 Ingress |
| 未来 Java/Python/Node demo | **E-W** 版本分流 | ⏳ 延期（需 sidecar 注入） |
| CloudOps 部分后端 | E-W 灰度 | ⏳ 延期 |

## 不进入 Mesh（明确）

| 类别 | 示例 |
|------|------|
| CI/CD | Jenkins、Argo CD |
| 制品 | Harbor |
| 集群管理 | Rancher |
| 可观测 | Prometheus、VictoriaLogs、Tempo、Alloy、Grafana |
| 数据 | MySQL、Redis、Postgres（含 cicd Release DB） |
| 入口存量 | 现网 Ingress NGINX 主路径（切流另案） |

## 南北向 vs 东西向

```text
N-S：客户端 → Ingress / Istio Gateway → 服务（lab 已演示）
E-W：服务 A → 服务 B 的 v1/v2 比例（需双方或客户端侧 mesh；延期）
```

## 流量治理实验状态

| 能力 | 状态 |
|------|------|
| VS 权重 + Rollouts | ✅ N-S 演示 |
| Header 匹配 | ✅ 文档与并行路径（见 header-tenant 文档） |
| timeout / retry / circuit breaker | ⏳ **默认网关路径启用**延期；并行 chart 可参考 traffic-policy 文档，勿未确认改主入口 |
| STRICT mTLS / AuthorizationPolicy | ⏳ 延期 |

详见 [deferred-week12-14-runtime-followups.md](deferred-week12-14-runtime-followups.md)。
