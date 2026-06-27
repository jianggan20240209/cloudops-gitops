# Istio + Argo Rollouts 精确流量灰度

## 目标

本阶段进入第 14 周：Istio 服务网格与流量治理。

目标不是替换现有 `cloudops-gateway`，而是先用独立 `rollouts-demo-istio` 验证：

- Istio control plane GitOps 安装
- Istio ingress gateway GitOps 安装
- Argo Rollouts 通过 Istio `VirtualService` 精确控制流量权重
- Prometheus `AnalysisTemplate` 继续参与 canary 阶段判断

## 版本

```text
Istio: 1.30.2
Argo Rollouts: 1.9.0
```

Istio 使用官方 Helm repo：

```text
https://istio-release.storage.googleapis.com/charts
```

## GitOps 目录

```text
dev/platform/
  argocd/
    project/dev-platform-project.yaml
    application/istio-base-dev.yaml
    application/istiod-dev.yaml
    application/istio-ingressgateway-dev.yaml
    application/rollouts-demo-istio-dev.yaml
  rollouts/
    demo-istio/
      rollout.yaml
      service-stable.yaml
      service-canary.yaml
      gateway.yaml
      virtualservice.yaml
      analysis-template.yaml
      servicemonitor.yaml
```

Istio `base`、`istiod`、`gateway` 使用官方 Helm chart，values 直接内联在对应 Argo CD Application 中，避免依赖 Argo CD multi-source values 能力。

## 部署顺序

注意：Istio `base`、`istiod`、`ingressgateway` 建议按顺序同步。`rollouts-demo-istio` 需要等 ingress gateway 外部地址和 DNS 准备好后再做访问验证。

先更新平台 AppProject：

```bash
kubectl apply -f dev/platform/argocd/project/dev-platform-project.yaml
```

部署 Istio CRD / base：

```bash
kubectl apply -f dev/platform/argocd/application/istio-base-dev.yaml
kubectl -n argocd get application istio-base-dev
kubectl get crd | grep istio.io
```

部署 istiod：

```bash
kubectl apply -f dev/platform/argocd/application/istiod-dev.yaml
kubectl -n argocd get application istiod-dev
kubectl -n istio-system get deploy,pod,svc
```

部署 Istio ingress gateway：

```bash
kubectl apply -f dev/platform/argocd/application/istio-ingressgateway-dev.yaml
kubectl -n argocd get application istio-ingressgateway-dev
kubectl -n istio-ingress get deploy,pod,svc
```

确认 `istio-ingressgateway` 的外部地址：

```bash
kubectl -n istio-ingress get svc
```

将 `istio-rollouts-demo.jianggan.cn` 解析到 `istio-ingressgateway` 的 LoadBalancer IP。

部署 Istio demo：

```bash
kubectl apply -f dev/platform/argocd/application/rollouts-demo-istio-dev.yaml
kubectl -n argocd get application rollouts-demo-istio-dev
kubectl -n cloudops-dev get rollout,svc,gateway,virtualservice,servicemonitor | grep rollouts-demo-istio
```

## 流量治理模型

普通 `rollouts-demo` 是基础 canary，靠 ReplicaSet 副本比例近似灰度。

`rollouts-demo-istio` 使用精确流量治理：

```text
Istio Gateway
  -> VirtualService rollouts-demo-istio
     -> rollouts-demo-istio-stable Service
     -> rollouts-demo-istio-canary Service
```

Argo Rollouts 修改 `VirtualService` 中 route 的权重：

```yaml
trafficRouting:
  istio:
    virtualService:
      name: rollouts-demo-istio
      routes:
        - primary
```

Canary 阶段：

```text
25% -> AnalysisRun -> 50% -> AnalysisRun -> 100%
```

## 验证命令

查看 Rollout：

```bash
kubectl -n cloudops-dev get rollout rollouts-demo-istio
kubectl -n cloudops-dev describe rollout rollouts-demo-istio
```

查看 VirtualService 权重：

```bash
kubectl -n cloudops-dev get virtualservice rollouts-demo-istio -o yaml
```

查看 stable / canary Service：

```bash
kubectl -n cloudops-dev get svc rollouts-demo-istio-stable rollouts-demo-istio-canary
```

验证 Prometheus target：

```bash
kubectl -n cloudops-dev get servicemonitor rollouts-demo-istio

kubectl -n monitoring run curl-prom-rollouts-demo-istio-query \
  --rm -i --restart=Never \
  --image=curlimages/curl:8.16.0 \
  -- curl -s 'http://kube-prometheus-stack-prometheus:9090/api/v1/query?query=sum(up%7Bnamespace%3D%22cloudops-dev%22%2Cservice%3D~%22rollouts-demo-istio-%28stable%7Ccanary%29%22%7D)%20OR%20on()%20vector(0)'
```

触发 canary 后观察：

```bash
kubectl -n cloudops-dev get rollout rollouts-demo-istio -w
kubectl -n cloudops-dev get analysisrun -w
kubectl -n cloudops-dev get rs -l app=rollouts-demo-istio -w
kubectl -n cloudops-dev get pod -l app=rollouts-demo-istio -w
```

## AnalysisRun 故障记录

首次触发 `rollouts-demo-istio` canary 时，Rollout 能进入 25% 阶段，但随后被 AnalysisRun 中止：

```text
RolloutAborted: Step-based analysis phase error/failed
Metric "service-up" assessed Error due to consecutiveErrors
Error Message: could not evaluate successCondition "result[0] >= 1":
metric result is nil or empty: no data returned from the metric provider
```

原因：

```text
AnalysisTemplate 使用 sum(up{job="rollouts-demo-istio"})
Prometheus 中该 job label 没有匹配到序列
sum() 对空向量返回空结果，导致 result[0] 不存在
```

修复：

```text
改为按 ServiceMonitor 生成的 service 标签查询 stable / canary Service：
sum(up{namespace="cloudops-dev",service=~"rollouts-demo-istio-(stable|canary)"}) OR on() vector(0)

OR on() vector(0) 用于保证无数据时返回 0，而不是空数组。
同时将 count 调整为 3、failureLimit 调整为 3，避免 target 刚创建或 Prometheus 尚未 scrape 时误判。
```

## Istio 精确灰度验证结果

验证时间：2026-06-27

本次通过 GitOps 修改 `rollouts-demo-istio` 镜像 tag，触发了一次 Argo Rollouts + Istio 的精确流量灰度。修复 Prometheus 查询后，新 Revision 已完成发布。

Rollout 状态：

```text
rollouts-demo-istio:
  desired: 2
  current: 2
  up-to-date: 2
  available: 2

Conditions:
  Completed: True / RolloutCompleted
  Healthy: True / RolloutHealthy
  Available: True / AvailableReason
  Progressing: True / NewReplicaSetAvailable

stable ReplicaSet:
  rollouts-demo-istio-676df55fd7
  desired/current/ready: 2/2/2

old ReplicaSet:
  rollouts-demo-istio-78c58557d
  desired/current/ready: 0/0/0
```

Istio `VirtualService` 最终权重：

```text
rollouts-demo-istio-stable:
  weight: 100

rollouts-demo-istio-canary:
  weight: 0
```

验证结论：

```text
Istio ingressgateway 访问链路正常
Argo Rollouts 能通过 Istio VirtualService 控制 stable / canary 权重
Prometheus AnalysisTemplate 修复后不再因为 no data 中止
rollouts-demo-istio 已完成一次精确流量灰度发布
```

## cloudops-cicd 查询接口

`cloudops-cicd` 已接入 Kubernetes API，可以读取 Rollout / AnalysisRun 状态：

验证前置条件：必须先重新运行 `test-cloudops-cicd-kaniko`，让线上 `cloudops-cicd` 镜像包含 `rollouts-demo-istio` 应用清单和 `/rollout`、`/analysisruns` 新接口。否则旧版本会返回 `app_not_found`。

```bash
curl --ssl-no-revoke -k https://cloudops.jianggan.cn/api/v1/cicd/apps/rollouts-demo-istio/rollout
curl --ssl-no-revoke -k https://cloudops.jianggan.cn/api/v1/cicd/apps/rollouts-demo-istio/analysisruns
curl --ssl-no-revoke -k https://cloudops.jianggan.cn/api/v1/cicd/apps/rollouts-demo-istio/release
```

应用存在同名 Rollout 时，`/release` 和 Release Record `verification` 会附带 `rollout` 摘要，并增加 `rollout_health` 检查项。

对于 Istio / Rollout 应用，Prometheus 指标不一定存在 `job=<app-name>`。`cloudops-cicd` 会先查询 `up{job="<app-name>"}`，如果没有 target，会回退到：

```text
up{namespace="<namespace>",service="<app-name>"}
or
up{namespace="<namespace>",service=~"<app-name>-(stable|canary)"}
```

因此 `rollouts-demo-istio` 的 `/release` 会使用 stable/canary ServiceMonitor target 判断 `prometheus_up`。

最终聚合验证结果：

```text
验证时间：2026-06-27
验证接口:
  GET /api/v1/cicd/apps/rollouts-demo-istio/release

Argo CD:
  sync: Synced
  health: Healthy
  revision: b2eae9111d44d44b160119bdfeb2f1e483472a5d

Harbor:
  current_tag: main-14
  image digest: sha256:d30a2037366fd371e58fbf2d2b6543e4ee1cdeb3bc7016e6f1ad79eef745fe9b

Prometheus:
  up: 4
  targets: 4
  healthy: true

Rollout:
  phase: Healthy
  stable_rs: rollouts-demo-istio-676df55fd7
  replicas: 2
  updated_replicas: 2
  available_replicas: 2

Checks:
  argocd_sync: pass
  argocd_health: pass
  image_tag: pass
  harbor_image: pass
  prometheus_up: pass
  rollout_health: pass

结论:
  ready: true
```

## 后续

- 已新增 `cloudops-gateway-rollout` 并行灰度版本，用于验证真实服务 Rollout + Istio。
- 后续根据验证结果评估是否将原 `cloudops-gateway-dev` 替换为 Rollout + Istio。
- 设计 tenant/header 路由灰度作为企业生产场景增强能力。
