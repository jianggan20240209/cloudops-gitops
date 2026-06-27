# Argo Rollouts 1.9.0 GitOps 部署说明

## 目标

本次先完成 Argo Rollouts 基础能力接入，不直接改造现有 `cloudops-gateway`、`cloudops-cicd` 发布链路。

范围：

- 安装 Argo Rollouts Controller 和 CRD，版本固定为 `v1.9.0`。
- 安装 Argo Rollouts Dashboard，镜像固定为 `quay.io/argoproj/kubectl-argo-rollouts:v1.9.0`。
- 暴露 Dashboard 到 `https://rollouts.jianggan.cn`。
- 新增独立 `rollouts-demo` canary 示例，不影响现有业务服务。

## GitOps 目录

```text
dev/platform/
  argocd/
    project/dev-platform-project.yaml
    application/argo-rollouts-dev.yaml
    application/argo-rollouts-dashboard-dev.yaml
    application/argo-rollouts-dashboard-ingress-dev.yaml
    application/rollouts-demo-dev.yaml
  rollouts/
    dashboard-ingress/ingress.yaml
    demo/rollout.yaml
    demo/service.yaml
    demo/ingress.yaml
```

## 部署顺序

先创建 AppProject：

```bash
kubectl apply -f dev/platform/argocd/project/dev-platform-project.yaml
```

再创建 Argo Rollouts Controller：

```bash
kubectl apply -f dev/platform/argocd/application/argo-rollouts-dev.yaml
kubectl -n argocd get application argo-rollouts-dev
```

确认 Controller 和 CRD：

```bash
kubectl get crd | grep argoproj.io
kubectl -n argo-rollouts get deploy,pod,svc
```

再创建 Dashboard 和 Ingress：

```bash
kubectl apply -f dev/platform/argocd/application/argo-rollouts-dashboard-dev.yaml
kubectl apply -f dev/platform/argocd/application/argo-rollouts-dashboard-ingress-dev.yaml

kubectl -n argocd get application argo-rollouts-dashboard-dev argo-rollouts-dashboard-ingress-dev
kubectl -n argo-rollouts get deploy,svc,ingress
```

访问：

```text
https://rollouts.jianggan.cn
```

最后创建 demo：

```bash
kubectl apply -f dev/platform/argocd/application/rollouts-demo-dev.yaml
kubectl -n argocd get application rollouts-demo-dev
kubectl -n cloudops-dev get rollout,rs,pod,svc,ingress | grep rollouts-demo
```

访问：

```text
https://rollouts-demo.jianggan.cn
```

## 验证 Rollout

安装 kubectl 插件后可使用：

```bash
kubectl argo rollouts version
kubectl argo rollouts get rollout rollouts-demo -n cloudops-dev
```

也可以直接使用 Kubernetes API：

```bash
kubectl -n cloudops-dev describe rollout rollouts-demo
kubectl -n cloudops-dev get rollout rollouts-demo -o yaml
```

观察 Rollout 变更时，分别 watch Rollout 和 Pod / ReplicaSet：

```bash
kubectl -n cloudops-dev get rollout rollouts-demo -w
kubectl -n cloudops-dev get rs -l app=rollouts-demo -w
kubectl -n cloudops-dev get pod -l app=rollouts-demo -w
```

注意：当前环境里 `kubectl get rs,pod -l app=rollouts-demo -w` 会报 `you may only specify a single resource type`，因此不要把多种资源类型合并到同一个 watch 命令。

## 初始部署验证结果

验证时间：2026-06-26

Argo CD Application：

```text
argo-rollouts-dev                     Synced / Healthy
argo-rollouts-dashboard-dev           Synced / Healthy
argo-rollouts-dashboard-ingress-dev   Synced / Healthy
rollouts-demo-dev                     Synced / Healthy
```

Argo Rollouts 组件：

```text
deployment/argo-rollouts             1/1
deployment/argo-rollouts-dashboard   1/1
pod/argo-rollouts-*                  Running
pod/argo-rollouts-dashboard-*        Running
service/argo-rollouts-dashboard      3100/TCP
ingress/argo-rollouts-dashboard      rollouts.jianggan.cn
```

Demo Rollout：

```text
rollout/rollouts-demo                Healthy / Completed
replicas:                            2
availableReplicas:                   2
stableRS:                            rollouts-demo-7dd7d49744
image:                               harbor-server.jianggan.cn/cloudops/cloudops-gateway:main-14
ingress:                             rollouts-demo.jianggan.cn
```

## Canary Demo

当前 `rollouts-demo` 使用已有 Harbor 镜像，避免额外拉取外部 demo 镜像：

```text
harbor-server.jianggan.cn/cloudops/cloudops-gateway:main-14
```

Canary 步骤：

```yaml
steps:
  - setWeight: 25
  - pause:
      duration: 60s
  - analysis:
      templates:
        - templateName: rollouts-demo-prometheus
  - setWeight: 50
  - pause:
      duration: 60s
  - analysis:
      templates:
        - templateName: rollouts-demo-prometheus
  - setWeight: 100
```

后续可以通过 GitOps 修改 `dev/platform/rollouts/demo/rollout.yaml` 中的镜像 tag 触发 canary。

## Prometheus AnalysisTemplate

本阶段在通用流量比例灰度基础上增加 Prometheus 指标判断。`rollouts-demo` 会继续使用 25% -> 50% -> 100% 的 canary 流程，但在 25% 和 50% 阶段后各执行一次 AnalysisRun。

新增资源：

```text
dev/platform/rollouts/demo/analysis-template.yaml
dev/platform/rollouts/demo/servicemonitor.yaml
```

ServiceMonitor：

```text
name: rollouts-demo
namespace: cloudops-dev
path: /metrics
port: http
interval: 30s
```

AnalysisTemplate：

```text
name: rollouts-demo-prometheus
provider: prometheus
address: http://kube-prometheus-stack-prometheus.monitoring.svc:9090
query: sum(up{job="rollouts-demo"})
successCondition: result[0] >= 1
failureLimit: 1
```

部署后先确认 Prometheus target：

```bash
kubectl -n cloudops-dev get servicemonitor rollouts-demo

kubectl -n monitoring run curl-prom-rollouts-demo-query \
  --rm -i --restart=Never \
  --image=curlimages/curl:8.16.0 \
  -- curl -s 'http://kube-prometheus-stack-prometheus:9090/api/v1/query?query=sum(up%7Bjob%3D%22rollouts-demo%22%7D)'
```

触发下一次 canary 后观察：

```bash
kubectl -n cloudops-dev get rollout rollouts-demo -w
kubectl -n cloudops-dev get analysisrun -w
kubectl -n cloudops-dev describe analysisrun
```

预期：

```text
25% 阶段后生成 AnalysisRun
AnalysisRun Successful 后进入 50%
50% 阶段后再次生成 AnalysisRun
第二次 AnalysisRun Successful 后进入 100%
```

## Canary 变更验证结果

验证时间：2026-06-27

本次通过修改 `rollouts-demo` 镜像 tag 触发了一次真实 canary 变更，Dashboard 已观察到 canary 阶段推进。

阶段观察：

```text
Revision 3:
  canary weight: 25
  new ReplicaSet: rollouts-demo-7dd7d49744
  old ReplicaSet: rollouts-demo-5c8599cb49
  状态: 新版本开始接管流量，旧版本仍保留 Pod

Revision 3:
  canary weight: 100
  new ReplicaSet: rollouts-demo-7dd7d49744
  old ReplicaSet: rollouts-demo-5c8599cb49
  状态: 新版本完成发布，旧版本缩容到 No Pods
```

验证结论：

```text
Argo Rollouts Controller 工作正常
Dashboard 可正确展示 canary 权重和 ReplicaSet 状态
rollouts-demo 已完成从旧 Revision 到新 Revision 的 canary 发布
当前 demo canary 基于固定步骤推进，尚未接入 Prometheus AnalysisTemplate
```

## 后续计划

- 为 `rollouts-demo` 增加 Prometheus `AnalysisTemplate`。
- 将 Rollout 阶段状态写入 `cloudops-cicd` Release Record。
- 将 `cloudops-gateway` 改造成 Rollout 资源。
- 支持灰度失败后的自动中止和人工回滚候选查询。
