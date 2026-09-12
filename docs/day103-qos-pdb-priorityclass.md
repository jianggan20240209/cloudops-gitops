# Day 103 · QoS / PDB / PriorityClass 规范

## QoS（提醒）

| 类 | 条件 | Lab 建议 |
|----|------|----------|
| Guaranteed | 每容器 request=limit | 关键控制面/少数核心服务 |
| Burstable | 有 request，limit 更大或不等 | **业务默认** |
| BestEffort | 无 request/limit | 仅一次性 Job / 实验，禁止长期业务 |

与 sidecar 同 Pod 时：按 [day97](day97-sidecar-cost-report-template.md) 计入总 request。

## PDB

- 多副本业务：`minAvailable` 或 `maxUnavailable` 二选一，避免驱逐时服务归零  
- 单副本：承认无 PDB 保护，发布/排水需人工窗口  
- 与 HPA：扩容后再收紧 PDB，避免无法驱逐阻塞升级

## PriorityClass

- 建议三级（名称示意）：`lab-high` / `lab-normal` / `lab-low`  
- 基础设施与观测关键路径可 `lab-high`；演练负载 `lab-low`  
- **禁止**随意创建高于系统关键类的优先级抢占生产稳定性

## 检查命令

```bash
kubectl get pdb -A
kubectl get priorityclass
kubectl get pod -n <ns> -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass
```

## 相关

- [day104-resource-recommendations.md](day104-resource-recommendations.md)
