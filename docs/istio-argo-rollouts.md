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
  -- curl -s 'http://kube-prometheus-stack-prometheus:9090/api/v1/query?query=sum(up%7Bjob%3D%22rollouts-demo-istio%22%7D)'
```

触发 canary 后观察：

```bash
kubectl -n cloudops-dev get rollout rollouts-demo-istio -w
kubectl -n cloudops-dev get analysisrun -w
kubectl -n cloudops-dev get rs -l app=rollouts-demo-istio -w
kubectl -n cloudops-dev get pod -l app=rollouts-demo-istio -w
```

## 后续

- 验证 `rollouts-demo-istio` 在 25%、50%、100% 阶段的 VirtualService 权重变化。
- 让 `cloudops-cicd` 读取 Rollout / AnalysisRun 状态并写入 Release Record。
- 将 `cloudops-gateway` 从 Deployment 迁移到 Rollout + Istio。
- 设计 tenant/header 路由灰度作为企业生产场景增强能力。
