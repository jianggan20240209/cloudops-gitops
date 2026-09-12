# Day 101 · HPA 演练计划（manifest 默认关闭）

状态：**计划 / Plan only**  
原则：YAML 可入库作参考，**默认不 apply**；live 压测见 [deferred-week15-22-runtime-followups.md](deferred-week15-22-runtime-followups.md)。

## 目标

在 **demo / 隔离 ns** 验证 HPA 扩缩与观测闭环；**不对** `cloudops.jianggan.cn` 主路径默认开启。

## 前置

- [ ] metrics-server（或自定义指标链路）可用  
- [ ] 目标 Deployment 已设合理 requests  
- [ ] 明确 min/max，避免打满节点  
- [ ] 演练窗口与回滚人已指定

## Manifest 约定

- 文件建议路径（示意）：`dev/platform/autoscaling/examples/hpa-*.yaml`  
- 注释头必须含：`# DEFAULT: OFF — apply only after explicit confirm`  
- `maxReplicas` 设硬顶；优先 CPU 70% 一类保守阈值

## 演练步骤（确认后）

1. apply HPA 到隔离 ns  
2. 受控加压（工具自选；避免全集群风暴）  
3. 观察：`kubectl get hpa -w`、Grafana、可选 Resource API  
4. 停止压测 → 等待缩容或手动 scale  
5. delete HPA / 恢复副本 → 记录 day90 风格复盘

## 明确不做（本计划）

- 不与 VPA 同对象同时启用（ADR-008）  
- 不做「load storm」打满 lab（deferred）

## 相关

- 桌面 ADR-008；[day102-vpa-keda-adr-pointer.md](day102-vpa-keda-adr-pointer.md)
