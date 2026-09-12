# Day 141–147 · 第 21 周索引（Operator 自愈）

桌面：`专用测试环境/42_第21周复盘_Operator自愈.md`  
ADR：桌面 `架构决策/ADR-011-RemediationOperator技术选型.md`（**Kubebuilder**）

## Day 映射

| Day | 交付 | 状态 |
|-----|------|------|
| 141 | CRD 草图：`RemediationRequest` | ✅ 文档 |
| 142 | 状态：PendingApproval / Approved / Running / Succeeded / Failed | ✅ |
| 143 | 动作白名单：restart pod、scale 边界内、切流量 abort 等 | ✅ 原则 |
| 144 | RBAC 最小权限 | ✅ 对齐 day69 |
| 145 | 与 Agent：Agent 只创建/更新「建议」字段 | ✅ |
| 146 | 审计与事件 | ✅ |
| 147 | **禁止**无审批 execute（deferred） | ✅ |

## CR 字段（示意）

```yaml
apiVersion: cloudops.jianggan.cn/v1alpha1
kind: RemediationRequest
metadata:
  name: example
spec:
  targetRef: { namespace: demo, kind: Deployment, name: app }
  action: RestartWorkload   # 白名单枚举
  reason: "OOM suggested by agent"
  approval: { required: true, approvedBy: "" }
status:
  phase: PendingApproval
```

## 非目标（本周）

- 不实现完整控制器发版  
- 不对 live 集群无审批执行  

## 相关

- [day148-154-week22-semi-auto-heal.md](day148-154-week22-semi-auto-heal.md)  
- [deferred-week15-22-runtime-followups.md](deferred-week15-22-runtime-followups.md)
