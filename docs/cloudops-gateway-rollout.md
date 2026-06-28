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

## 初始部署验证结果

验证时间：2026-06-27

Argo CD 和 Kubernetes 资源：

```text
cloudops-gateway-rollout-dev: Synced / Healthy
rollout/cloudops-gateway-rollout: desired=2, current=2, up-to-date=2, available=2
pod/cloudops-gateway-rollout-59ccd997fd-rcz6f: 1/1 Running
pod/cloudops-gateway-rollout-59ccd997fd-vpmqc: 1/1 Running
service/cloudops-gateway-rollout-stable: ClusterIP
service/cloudops-gateway-rollout-canary: ClusterIP
VirtualService host: istio-cloudops-gateway.jianggan.cn
```

Istio 入口验证：

```text
ingress gateway: 192.168.1.211
GET /readyz: {"service":"cloudops-gateway","status":"ready"}
GET /api/v1/version:
  service: cloudops-gateway
  version: main-14
  commit: c308075261dc
```

VirtualService 初始权重：

```text
cloudops-gateway-rollout-stable:
  weight: 100
cloudops-gateway-rollout-canary:
  weight: 0
```

发布中心聚合验证结果：

```text
验证接口:
  GET /api/v1/cicd/apps/cloudops-gateway-rollout/release

Argo CD:
  sync: Synced
  health: Healthy
  revision: f62a87e585051bb005cca26bd3f93c40dfbc7c7a

Harbor:
  current_tag: main-14
  image digest: sha256:d30a2037366fd371e58fbf2d2b6543e4ee1cdeb3bc7016e6f1ad79eef745fe9b

Prometheus:
  up: 4
  targets: 4
  healthy: true

Rollout:
  phase: Healthy
  stable_rs: cloudops-gateway-rollout-59ccd997fd
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

VirtualService:
  stable weight: 100
  canary weight: 0

结论:
  ready: true
```

## Canary 变更验证结果

验证时间：2026-06-28

本次通过修改 `cloudops-gateway-rollout` 镜像 tag，触发了一次真实服务的 Argo Rollouts + Istio 精确流量灰度。

Rollout 阶段观察：

```text
初始:
  desired/current/up-to-date/available: 2/2/2/2

25% canary:
  current: 3
  up-to-date: 1
  available: 3

50% canary:
  current: 4
  up-to-date: 2
  available: 4

完成:
  desired/current/up-to-date/available: 2/2/2/2
```

AnalysisRun：

```text
cloudops-gateway-rollout-75464d5c7f-2-2:
  status: Successful
  duration: 60s

cloudops-gateway-rollout-75464d5c7f-2-5:
  status: Successful
  duration: 60s
```

VirtualService 最终权重：

```text
cloudops-gateway-rollout-stable:
  weight: 100
cloudops-gateway-rollout-canary:
  weight: 0
```

验证结论：

```text
Argo Rollouts 能按 25% -> AnalysisRun -> 50% -> AnalysisRun -> 100% 推进真实服务灰度
Prometheus AnalysisRun 两次均 Successful
Istio VirtualService 最终回到 stable 100 / canary 0
cloudops-gateway-rollout 真实服务 canary 验证完成
```

## 后续

- 调用 `cloudops-cicd` Release Record snapshot 接口，将本次 Rollout / AnalysisRun 聚合结果持久化。
- 评估是否将原 `cloudops-gateway-dev` 替换为 Rollout + Istio 模式。

## Release Record 快照

灰度完成、失败或人工检查后，可以将当前聚合结果保存为 Release Record 快照：

```bash
curl --ssl-no-revoke -k -X POST \
  https://cloudops.jianggan.cn/api/v1/cicd/apps/cloudops-gateway-rollout/records/snapshot
```

快照内容包括：

```text
Argo CD sync / health / revision
Harbor image tag / digest
Prometheus up / targets / healthy
Rollout phase / stableRS / conditions
AnalysisRun phase / metricResults
ready / checks
```

快照 ID 会追加时间戳，避免覆盖同一个 imageTag 的基础记录。

快照写入验证结果：

```text
验证时间：2026-06-28
验证接口:
  POST /api/v1/cicd/apps/cloudops-gateway-rollout/records/snapshot

快照记录:
  id: dev-cloudops-gateway-rollout-main-13-snapshot-20260625154014
  app_name: cloudops-gateway-rollout
  image_tag: main-13
  jenkins_build: 13
  status: succeeded
  source: snapshot

Argo CD:
  sync: Synced
  health: Healthy
  revision: 77d7a9bbcc13de15c1b8acaed7f774f19fe4229d

Harbor:
  digest: sha256:4bc42510716fe90859015a14738d3b8c1e26cfe76c81ce95c5d64f0509c13a01

Prometheus:
  up: 4
  targets: 4
  healthy: true

Rollout:
  phase: Healthy
  stable_rs: cloudops-gateway-rollout-75464d5c7f
  replicas: 2
  updated_replicas: 2
  available_replicas: 2

AnalysisRun:
  cloudops-gateway-rollout-75464d5c7f-2-2: Successful
  cloudops-gateway-rollout-75464d5c7f-2-5: Successful

Checks:
  argocd_sync: pass
  argocd_health: pass
  image_tag: pass
  harbor_image: pass
  prometheus_up: pass
  rollout_health: pass

结论:
  Release Record 快照写入成功
```
