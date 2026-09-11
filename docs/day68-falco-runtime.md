# Day 68 · 运行时安全（Falco / eBPF）

完整：桌面 `专用测试环境/29_Falco运行时安全.md`

目标场景：异常 shell、特权容器、敏感路径写、容器漂移。

## 方案

- 优先：**Falco** DaemonSet（helm）+ 自定义规则 ConfigMap  
- 备选：Cilium Tetragon（后续）

清单：

- `dev/platform/security/falco/values-lab.yaml`
- `dev/platform/security/falco/rules-cloudops.yaml`
- `scripts/day68-falco-plan.sh`（打印安装命令，不默认安装）

安装：`CONFIRM=1 bash scripts/day68-falco-plan.sh`  

**延期**：集群建设完成前不安装。跟踪：`docs/deferred-week10-security-followups.md`
