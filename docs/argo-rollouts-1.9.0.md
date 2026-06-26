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
  - setWeight: 50
  - pause:
      duration: 60s
  - setWeight: 100
```

后续可以通过 GitOps 修改 `dev/platform/rollouts/demo/rollout.yaml` 中的镜像 tag 触发 canary。

## 后续计划

- 为 `rollouts-demo` 增加 Prometheus `AnalysisTemplate`。
- 将 Rollout 阶段状态写入 `cloudops-cicd` Release Record。
- 将 `cloudops-gateway` 改造成 Rollout 资源。
- 支持灰度失败后的自动中止和人工回滚候选查询。
