# Day 118 · RTO / RPO / 业务连续性（BC）

## 定义（lab 工作语言）

| 术语 | 含义 |
|------|------|
| RPO | 最多可丢失多长时间的数据（备份间隔上界） |
| RTO | 恢复服务可接受的最长时间 |
| BC | 人员 + 工具 + 演练 + 审批，使 RTO/RPO 可兑现 |

## Lab 目标分层（示例，可改）

| 对象 | 目标 RPO | 目标 RTO | 手段 |
|------|----------|----------|------|
| etcd / 控制面对象 | ≤ 24h | 数小时级（审批窗口） | day113 快照 |
| 无状态业务 | ≈ 0（GitOps） | 数十分钟 | Argo 重部署 |
| 有状态 PVC | 按卷备份频率 | 视 Longhorn/Velero | day114 + Longhorn |
| 发布误操作 | N/A | 快速 abort/回滚 | Rollouts + day90 |

## 门禁

- 未定义 RTO/RPO **不**对生产 ns 开自动备份删除策略  
- restore / delete-restore **必须**显式确认（deferred）  
- 复盘使用 day90 模板记录实际 RTO

## 相关

- [day119-week17-retro.md](day119-week17-retro.md)  
- 桌面第 17 周复盘
