# Day 65 · CloudOps 最小权限 RBAC

清单：`dev/platform/security/rbac/`

| 角色 | 能力 |
|------|------|
| `cloudops-readonly` | get/list/watch 核心资源 + 日志相关只读 |
| `cloudops-releaser` | 发布相关：Argo Application get/patch（限 cloudops-*）、Rollout 查看 |
| `cloudops-approver` | 审批语义（标注/注释）；无 delete ns |
| `cloudops-admin` | 平台 ns 内管理；**仍非** cluster-admin |

```bash
kubectl apply -f dev/platform/security/rbac/
# 绑定示例见 cloudops-rolebindings-example.yaml（默认不绑真人，避免误授权）
```
