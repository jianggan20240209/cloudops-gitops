# Day 69 · 安全事件接入与 AI/Operator/网格边界

完整：桌面 `专用测试环境/30_AI_Operator安全边界.md`

## 事件接入路径

```text
Falco / Harbor 扫描 / NetPol drop(Hubble)
  → Alertmanager（severity=P1/P2）
  → CloudOps /api/v1/observe/alerts
  → 审计字段：谁、何时、何对象、查询还是变更
```

## 边界原则

| 主体 | 允许 | 禁止 |
|------|------|------|
| AI Agent | 只读查询（日志/指标/告警/描述） | 未审批的 delete/scale/apply |
| Operator | Reconcile 声明式自愈（白名单动作） | 越权改 RBAC / 读全集群 Secret |
| Istio | 东西向授权 + mTLS | 用 mesh 替代 NS/NetPol 隔离 |

变更必须：**审批记录 + 全量审计**（Jenkins/Argo/CloudOps）。
