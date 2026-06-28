# cloudops-gateway Rollout + Istio 切换 Dry Run 评审记录

## 目标

在不切换 `cloudops.jianggan.cn` 正式入口的前提下，按 `cloudops-gateway-cutover-runbook.md` 执行 Go / No-Go 评审，判断是否具备后续正式迁移条件。

本次只做评审记录，不修改 DNS、Ingress、Gateway 或 VirtualService 运行态配置。

## 评审时间

```text
2026-06-28
```

## 评审范围

```text
当前正式入口:
  https://cloudops.jianggan.cn/api

并行灰度入口:
  istio-cloudops-gateway.jianggan.cn

并行灰度应用:
  cloudops-gateway-rollout-dev

迁移目标:
  从 Deployment + NGINX Ingress 模式迁移到 Argo Rollouts + Istio VirtualService 模式
```

## 当前验证证据

### cloudops-gateway-rollout

```text
cloudops-gateway-rollout-dev: Synced / Healthy
rollout/cloudops-gateway-rollout: Healthy
pod/cloudops-gateway-rollout: 2/2 Running
Istio VirtualService: stable 100 / canary 0
```

### Istio 入口

```text
istio-ingressgateway: Running
LoadBalancer IP: 192.168.1.211
Host: istio-cloudops-gateway.jianggan.cn
/readyz: ready
/api/v1/version: main-14
```

### 灰度发布能力

```text
canary 阶段:
  25% -> AnalysisRun -> 50% -> AnalysisRun -> 100%

AnalysisRun:
  cloudops-gateway-rollout-75464d5c7f-2-2: Successful
  cloudops-gateway-rollout-75464d5c7f-2-5: Successful
```

### 发布中心聚合

```text
cloudops-cicd /release:
  app: cloudops-gateway-rollout
  argocd_sync: pass
  argocd_health: pass
  harbor_image: pass
  prometheus_up: pass
  rollout_health: pass
  ready: true
```

### Release Record 快照

```text
snapshot id:
  dev-cloudops-gateway-rollout-main-13-snapshot-20260625154014

source:
  snapshot

status:
  succeeded
```

## Go / No-Go 检查

| 检查项 | 状态 | 证据 | 结论 |
|---|---|---|---|
| 原 `cloudops-gateway-dev` 路径健康 | 待正式窗口复核 | `https://cloudops.jianggan.cn/api/readyz` | Go 前必须复核 |
| `cloudops-gateway-rollout` 并行路径健康 | 已通过 | `istio-cloudops-gateway.jianggan.cn` 返回 ready/version | Go |
| Rollout 状态健康 | 已通过 | Rollout Healthy / Completed | Go |
| Prometheus target 健康 | 已通过 | `up=4, targets=4` | Go |
| AnalysisRun 可成功 | 已通过 | 两个 AnalysisRun Successful | Go |
| 发布中心聚合 ready | 已通过 | `/release ready=true` | Go |
| Release Record 快照可写入 | 已通过 | snapshot succeeded | Go |
| DNS/LB 回退路径明确 | 已设计，待窗口确认 | Runbook 中 DNS/LB 回退 | Go 前必须复核 |
| 前端 `/` 路由不受影响 | 待方案确认 | 当前 Istio 只验证 API 能力 | No-Go，若切原域名需补前端路由 |

## 评审结论

```text
技术链路具备正式迁移基础:
  Argo Rollouts
  Istio VirtualService
  Prometheus AnalysisRun
  cloudops-cicd Release 聚合
  PostgreSQL Release Record snapshot

当前不建议立即切换 cloudops.jianggan.cn 整站入口。
```

原因：

```text
cloudops.jianggan.cn 当前同时承载:
  /     前端页面
  /api  gateway API

当前 Istio 并行验证只覆盖 gateway API。
如果直接把 cloudops.jianggan.cn DNS 指向 Istio ingressgateway，前端 / 路由可能受影响。
```

## 推荐下一步

优先选择以下二选一方案：

```text
方案 A:
  新增 api.cloudops.jianggan.cn
  只将 API 流量切到 Istio
  保持 cloudops.jianggan.cn 前端入口不变

方案 C:
  保持 NGINX Ingress 为统一入口
  由 NGINX 将 /api 转发到 Istio ingressgateway
  前端 / 路由继续由 NGINX 处理
```

当前执行状态：

```text
已按方案 A 新增 api.cloudops.jianggan.cn 的 Gateway / VirtualService / Certificate 配置。
仍需在 DNS 中将 api.cloudops.jianggan.cn 解析到 istio-ingressgateway LoadBalancer IP 后验证。
```

暂不推荐：

```text
方案 B:
  直接让 Istio 接管 cloudops.jianggan.cn 整个域名
```

除非先补齐：

```text
Istio VirtualService 前端 / 路由
cloudops-web stable/canary 或普通 Service 路由
TLS Secret / Gateway HTTPS 配置
前端静态资源访问验证
```

## 正式切换前待办

```text
1. 在正式窗口复核 cloudops.jianggan.cn/api 当前 NGINX 路径健康。
2. 明确采用 api.cloudops.jianggan.cn 还是 NGINX -> Istio 转发方案。
3. 确认 DNS TTL 和回退耗时。
4. 准备切换前 Release Record snapshot。
5. 准备切换后 Release Record snapshot。
6. 准备 DNS/LB 回退命令或变更单。
```

## 结论状态

```text
Dry Run 结论:
  技术能力: GO
  正式入口切换: CONDITIONAL GO

必须先解决:
  前端 / 路由边界
  DNS/LB 回退确认
```
