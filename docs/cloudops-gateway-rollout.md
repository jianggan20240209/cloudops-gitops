# cloudops-gateway Rollout 并行灰度

## 目标

本阶段将真实服务 `cloudops-gateway` 以并行方式接入 Argo Rollouts + Istio 精确流量灰度。

设计原则：

- 不替换现有 `cloudops-gateway-dev`。
- 不影响当前 `https://cloudops.jianggan.cn/api` 入口。
- 新增独立 Rollout 应用 `cloudops-gateway-rollout-dev`。
- 使用独立域名 `istio-cloudops-gateway.jianggan.cn` 验证流量治理。

## GitOps 目录

```text
dev/backend/argocd/application/cloudops-gateway-rollout-dev.yaml

dev/backend/rollouts/cloudops-gateway/
  rollout.yaml
  service-stable.yaml
  service-canary.yaml
  gateway.yaml
  virtualservice.yaml
  analysis-template.yaml
  servicemonitor.yaml
```

## 流量模型

```text
client
  -> istio-ingressgateway
  -> Gateway cloudops-gateway-rollout
  -> VirtualService cloudops-gateway-rollout
     -> cloudops-gateway-rollout-stable
     -> cloudops-gateway-rollout-canary
```

Argo Rollouts 负责调整 `VirtualService` 权重：

```text
25% -> AnalysisRun -> 50% -> AnalysisRun -> 100%
```

## 部署

```bash
kubectl apply -f dev/backend/argocd/application/cloudops-gateway-rollout-dev.yaml

kubectl -n argocd get application cloudops-gateway-rollout-dev
kubectl -n cloudops-dev get rollout,svc,gateway,virtualservice,servicemonitor | grep cloudops-gateway-rollout
```

确认 `istio-ingressgateway` 地址：

```bash
kubectl -n istio-ingress get svc istio-ingressgateway
```

将 `istio-cloudops-gateway.jianggan.cn` 解析到 Istio ingress gateway 的 LoadBalancer IP。

## 验证入口

```bash
curl -H "Host: istio-cloudops-gateway.jianggan.cn" http://<istio-ingressgateway-ip>/readyz
curl -H "Host: istio-cloudops-gateway.jianggan.cn" http://<istio-ingressgateway-ip>/api/v1/version
```

## 验证 Prometheus

```bash
kubectl -n cloudops-dev get servicemonitor cloudops-gateway-rollout

kubectl -n monitoring run curl-prom-gateway-rollout-query \
  --rm -i --restart=Never \
  --image=curlimages/curl:8.16.0 \
  -- curl -s 'http://kube-prometheus-stack-prometheus:9090/api/v1/query?query=sum(up%7Bnamespace%3D%22cloudops-dev%22%2Cservice%3D~%22cloudops-gateway-rollout-%28stable%7Ccanary%29%22%7D)%20OR%20on()%20vector(0)'
```

## 验证 Rollout

```bash
kubectl -n cloudops-dev get rollout cloudops-gateway-rollout
kubectl -n cloudops-dev describe rollout cloudops-gateway-rollout
kubectl -n cloudops-dev get virtualservice cloudops-gateway-rollout -o yaml | grep -A20 'route:'
```

触发 canary 后观察：

```bash
kubectl -n cloudops-dev get rollout cloudops-gateway-rollout -w
kubectl -n cloudops-dev get analysisrun -w
kubectl -n cloudops-dev get rs -l app=cloudops-gateway-rollout -w
kubectl -n cloudops-dev get pod -l app=cloudops-gateway-rollout -w
```

## 发布中心验证

`cloudops-cicd` 新版本包含 `cloudops-gateway-rollout` 应用清单后，可以验证：

```bash
curl --ssl-no-revoke -k https://cloudops.jianggan.cn/api/v1/cicd/apps/cloudops-gateway-rollout/rollout
curl --ssl-no-revoke -k https://cloudops.jianggan.cn/api/v1/cicd/apps/cloudops-gateway-rollout/analysisruns
curl --ssl-no-revoke -k https://cloudops.jianggan.cn/api/v1/cicd/apps/cloudops-gateway-rollout/release
```

预期：

```text
argocd_sync: pass
argocd_health: pass
image_tag: pass
harbor_image: pass
prometheus_up: pass
rollout_health: pass
ready: true
```

## 后续

- 验证 `cloudops-gateway-rollout` canary 完成。
- 将 `cloudops-cicd` Release Record 增加 Rollout 阶段事件持久化。
- 评估是否将原 `cloudops-gateway-dev` 替换为 Rollout + Istio 模式。
