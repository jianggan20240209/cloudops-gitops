# cloudops-gateway 迁移到 Rollout + Istio Runbook

## 目标

将当前 `cloudops-gateway` 的发布模式从普通 `Deployment + NGINX Ingress` 迁移到 `Argo Rollouts + Istio VirtualService`。

当前状态：

```text
生产入口:
  https://cloudops.jianggan.cn/api

当前实现:
  NGINX Ingress -> Service/cloudops-gateway -> Deployment/cloudops-gateway

并行验证入口:
  istio-cloudops-gateway.jianggan.cn

并行实现:
  Istio ingressgateway -> Gateway -> VirtualService -> cloudops-gateway-rollout stable/canary
```

本 Runbook 只描述迁移方案和回退方案，不直接修改当前入口。

正式切换前的 Dry Run 评审记录见：

```text
docs/cloudops-gateway-cutover-dry-run.md
```

## 已完成前置验证

```text
cloudops-gateway-rollout-dev: Synced / Healthy
Istio ingressgateway: Running
cloudops-gateway-rollout: Healthy
VirtualService: stable 100 / canary 0
Prometheus AnalysisRun: Successful
cloudops-cicd /release: ready=true
Release Record snapshot: succeeded
```

## 迁移策略

推荐采用 DNS / 入口切换方式，而不是直接删除原 NGINX Ingress。

原因：

```text
1. 原入口 cloudops.jianggan.cn 仍承载前端和 /api 路由。
2. 直接改原 Ingress 风险较高，回退需要恢复 Ingress 资源。
3. DNS / LB 切换可以保留原 NGINX 路径，回退更快。
```

## 迁移阶段

### 阶段 0：冻结变更

迁移窗口内暂停：

```text
cloudops-gateway-dev Jenkins 发布
cloudops-gateway-rollout 镜像 tag 变更
cloudops-web 入口变更
Ingress / Istio Gateway 相关手工改动
```

记录当前状态：

```bash
kubectl -n argocd get application cloudops-gateway-dev cloudops-gateway-rollout-dev
kubectl -n cloudops-dev get deploy,rollout,svc,ingress,gateway,virtualservice | grep cloudops-gateway
kubectl -n istio-ingress get svc istio-ingressgateway
```

### 阶段 1：迁移前健康检查

原路径检查：

```bash
curl --ssl-no-revoke -k https://cloudops.jianggan.cn/api/readyz
curl --ssl-no-revoke -k https://cloudops.jianggan.cn/api/v1/version
```

Istio 并行路径检查：

```bash
ISTIO_LB_IP="$(kubectl -n istio-ingress get svc istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"

curl -H "Host: istio-cloudops-gateway.jianggan.cn" http://${ISTIO_LB_IP}/readyz
curl -H "Host: istio-cloudops-gateway.jianggan.cn" http://${ISTIO_LB_IP}/api/v1/version
```

发布中心检查：

```bash
curl --ssl-no-revoke -k https://cloudops.jianggan.cn/api/v1/cicd/apps/cloudops-gateway-rollout/release
```

要求：

```text
cloudops-gateway-rollout /release ready=true
prometheus_up=pass
rollout_health=pass
VirtualService stable=100 canary=0
```

### 阶段 2：准备正式域名 Gateway

在正式切换前，需要为 Istio 增加 `cloudops.jianggan.cn` host。

建议新增独立 `Gateway/VirtualService` 变更，而不是复用 demo host：

```text
Gateway host:
  cloudops.jianggan.cn

VirtualService match:
  /api

Route:
  cloudops-gateway-rollout-stable weight 100
  cloudops-gateway-rollout-canary weight 0
```

注意：

```text
如果 cloudops.jianggan.cn 仍有前端 / 路由在 NGINX Ingress 上，
则不要直接把整个域名 DNS 切到 Istio，除非 Istio 也接管前端路由。
```

可选切换方案：

```text
方案 A:
  只为 API 使用独立域名 api.cloudops.jianggan.cn，切到 Istio。

方案 B:
  让 Istio 接管 cloudops.jianggan.cn，并同时配置前端 / 路由。

方案 C:
  保持 NGINX Ingress 作为入口，在 NGINX 层转发 /api 到 Istio Gateway。
```

当前个人实验建议优先使用方案 A 或 C，避免影响前端。

## 方案 A 落地配置

已为 `cloudops-gateway-rollout` 增加 API 独立域名：

```text
api.cloudops.jianggan.cn
```

GitOps 清单：

```text
dev/backend/rollouts/cloudops-gateway/certificate-api.yaml
dev/backend/rollouts/cloudops-gateway/gateway.yaml
dev/backend/rollouts/cloudops-gateway/virtualservice.yaml
```

配置内容：

```text
Certificate:
  api-cloudops-jianggan-cn
  secretName: api-cloudops-jianggan-cn-tls
  issuer: jianggan-ca-issuer

Gateway:
  HTTP 80:
    istio-cloudops-gateway.jianggan.cn
    api.cloudops.jianggan.cn
  HTTPS 443:
    api.cloudops.jianggan.cn
    credentialName: api-cloudops-jianggan-cn-tls

VirtualService:
  hosts:
    istio-cloudops-gateway.jianggan.cn
    api.cloudops.jianggan.cn
  route:
    cloudops-gateway-rollout-stable weight 100
    cloudops-gateway-rollout-canary weight 0
```

DNS：

```text
api.cloudops.jianggan.cn -> istio-ingressgateway LoadBalancer IP
```

验证：

```bash
ISTIO_LB_IP="$(kubectl -n istio-ingress get svc istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"

curl -H "Host: api.cloudops.jianggan.cn" http://${ISTIO_LB_IP}/readyz
curl -H "Host: api.cloudops.jianggan.cn" http://${ISTIO_LB_IP}/api/v1/version

curl --ssl-no-revoke -k https://api.cloudops.jianggan.cn/readyz
curl --ssl-no-revoke -k https://api.cloudops.jianggan.cn/api/v1/version
```

方案 A 回退：

```text
将 api.cloudops.jianggan.cn DNS 解析回原 NGINX Ingress / 原 API 入口，或直接移除该域名解析。
```

### 阶段 3：正式切流

如果使用独立 API 域名：

```text
api.cloudops.jianggan.cn -> Istio ingressgateway LoadBalancer IP
```

如果使用原域名切换：

```text
cloudops.jianggan.cn -> Istio ingressgateway LoadBalancer IP
```

切换后验证：

```bash
curl --ssl-no-revoke -k https://cloudops.jianggan.cn/api/readyz
curl --ssl-no-revoke -k https://cloudops.jianggan.cn/api/v1/version

kubectl -n cloudops-dev get virtualservice cloudops-gateway-rollout -o yaml | grep -A20 'route:'
curl --ssl-no-revoke -k https://cloudops.jianggan.cn/api/v1/cicd/apps/cloudops-gateway-rollout/release
```

### 阶段 4：发布记录快照

切流完成后立即保存发布记录：

```bash
curl --ssl-no-revoke -k -X POST \
  https://cloudops.jianggan.cn/api/v1/cicd/apps/cloudops-gateway-rollout/records/snapshot
```

记录：

```text
切换时间
切换前入口 IP
切换后入口 IP
cloudops-gateway-rollout image tag
release snapshot id
```

## 回退方案

### 快速回退：DNS / LB 回退

如果正式切换后出现异常，优先回退入口：

```text
cloudops.jianggan.cn -> 原 NGINX Ingress LoadBalancer IP
```

或：

```text
api.cloudops.jianggan.cn -> 原 API 入口
```

验证：

```bash
curl --ssl-no-revoke -k https://cloudops.jianggan.cn/api/readyz
curl --ssl-no-revoke -k https://cloudops.jianggan.cn/api/v1/version
```

### 应用层回退：Rollout 回退

如果问题只出现在新 image tag：

```bash
kubectl argo rollouts undo cloudops-gateway-rollout -n cloudops-dev
```

无插件时：

```text
通过 GitOps 将 dev/backend/rollouts/cloudops-gateway/rollout.yaml 的 image tag 改回上一版本。
```

### GitOps 回退

查看最近提交：

```bash
git log --oneline -- dev/backend/rollouts/cloudops-gateway docs/cloudops-gateway-rollout.md
```

创建回退提交：

```bash
git revert <bad-commit>
git push
```

Argo CD 同步：

```bash
kubectl -n argocd annotate application cloudops-gateway-rollout-dev \
  argocd.argoproj.io/refresh=hard \
  --overwrite
```

## 风险评估表

| 风险项 | 等级 | 影响 | 缓解措施 |
|---|---|---|---|
| DNS 切换影响前端入口 | 高 | `cloudops.jianggan.cn/` 访问异常 | 优先独立 API 域名或同时配置前端路由 |
| Istio ingressgateway 异常 | 高 | API 不可访问 | 保留 NGINX Ingress 原路径，DNS 快速回退 |
| VirtualService 配置错误 | 中 | 404/503 | 切换前用 Host header 直接访问 Istio LB |
| AnalysisTemplate 误判 | 中 | 灰度中止 | 使用 `OR vector(0)`，保留人工 promote/abort |
| Release Record 未写入 | 低 | 审计缺失 | 切换后手动调用 snapshot 接口 |

## Go / No-Go 检查表

Go 条件：

```text
cloudops-gateway-dev 原路径健康
cloudops-gateway-rollout 并行路径健康
Prometheus target healthy
Rollout Healthy
Release /release ready=true
回退 DNS / GitOps 操作已确认
```

No-Go 条件：

```text
Istio ingressgateway 非 Running
VirtualService 无法访问 /readyz
Prometheus target 为 0
Rollout 非 Healthy
cloudops-cicd /release ready=false
```
