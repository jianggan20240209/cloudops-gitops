# Day 64 · K8s 安全基线清单

完整：桌面 `专用测试环境/25_K8s安全基线清单.md`

| 域 | 基线要求（lab） |
|----|-----------------|
| RBAC | 禁止业务默认 `cluster-admin`；角色分只读/发布/审批/管理员 |
| ServiceAccount | 工作负载用专用 SA；关闭不必要的 automount |
| Secret | TLS 用 cert-manager；凭据进 Secret，不进 Git |
| Pod Security | 业务 ns 倾向 `baseline`/`restricted`；演练 ns 可放宽并隔离 |
| SecurityContext | 非 root、禁止特权、只读根文件系统（能开则开） |
| 审计 | API server audit（kubeasz 已有则记录路径）；变更留 Argo/Jenkins 痕迹 |

检查脚本：`scripts/day64-check-security-baseline.sh`
