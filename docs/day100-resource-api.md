# Day 100 · Resource API 设计（observe 扩展）

## 目标

在 CloudOps observe 叙事下增加**只读**资源画像 API（实现可后置；本文件定契约）。

## 建议契约

```http
GET /api/v1/observe/resources?namespace=&workload=
GET /api/v1/observe/resources/{namespace}/{workload}
```

响应：对齐 [day99-resource-profile.md](day99-resource-profile.md) 字段；可附 `recommendations[]` 摘要（详见 day104）。

## 数据源优先级

1. Kubernetes API（Deploy/HPA/PDB）  
2. metrics-server / Prometheus（用量）  
3. 静态标注（sidecar / 业务等级）

## 安全

- 只读；RBAC 最小 list/get  
- **不**返回 Secret / 凭证  
- 与现有 observe 一致：经 CloudOps 网关，审计「谁查询了何 ns」

## 既有 observe 入口（复用）

| 能力 | 路径 |
|------|------|
| 日志 | `GET /api/v1/observe/logs`（day47） |
| 告警 | `GET /api/v1/observe/alerts`（day59） |
| 告警详情 | `GET /api/v1/observe/alerts/detail`（day60） |

## 相关

- [day105-week15-retro.md](day105-week15-retro.md)  
- 桌面 ADR-008
