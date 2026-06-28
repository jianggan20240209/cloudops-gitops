# cloudops-gateway Header / Tenant 灰度 Runbook

## 目标

在已经完成 `cloudops-gateway-rollout + Istio` 通用比例灰度的基础上，补充企业多租户场景常见的精准灰度能力：

```text
指定测试租户 / 指定生产租户 / 指定测试人员
  -> 命中 canary

其他请求
  -> 继续走 Argo Rollouts 管理的 stable/canary 权重路由
```

本 Runbook 只描述设计和演练方式，不自动修改当前生效的 `cloudops-gateway-rollout` VirtualService。

## 适用场景

适合：

```text
测试租户先行验证
小范围生产租户验证
指定测试人员账号验证
内部灰度开关验证
```

不适合：

```text
完全随机公网用户流量灰度
没有租户 ID / 用户 ID / Header 上下文的请求
```

## 推荐 Header 约定

```text
x-tenant-id:
  表示租户 ID，例如 test-tenant、prod-tenant-001。

x-canary-user:
  表示测试人员或灰度用户，例如 qa、sre、jianggan。

x-canary:
  手工灰度开关，例如 true。
```

## 路由优先级

Istio VirtualService 按 `http` 路由顺序从上到下匹配，因此 Header / Tenant 灰度路由必须放在 Argo Rollouts 管理的 `primary` 路由之前。

推荐顺序：

```text
1. tenant-canary:
   x-tenant-id in [test-tenant, prod-tenant-001]
   -> canary service 100%

2. user-canary:
   x-canary-user in [qa, sre]
   -> canary service 100%

3. manual-canary:
   x-canary: true
   -> canary service 100%

4. primary:
   由 Argo Rollouts 管理 stable / canary 权重
```

## 示例清单

示例文件：

```text
docs/examples/cloudops-gateway/header-tenant-virtualservice.yaml
```

注意：该文件不在任何 Argo CD Application 路径下，不会自动生效。正式使用前需要人工评审，并根据当前 `VirtualService` 权重和 Rollout 状态调整。

## 演练步骤

### 1. 确认当前 Rollout 健康

```bash
kubectl -n cloudops-dev get rollout cloudops-gateway-rollout
kubectl -n cloudops-dev get virtualservice cloudops-gateway-rollout -o yaml | grep -A30 'http:'
```

要求：

```text
Rollout Healthy
primary route 存在
stable/canary service 存在
```

### 2. 触发 canary revision

通过 GitOps 修改：

```text
dev/backend/rollouts/cloudops-gateway/rollout.yaml
```

将镜像 tag 改为新版本，等待 Argo Rollouts 进入 canary 阶段。

### 3. 应用 Header / Tenant 路由

仅在确认 canary service 有后端 Pod 后执行：

```bash
kubectl apply -f docs/examples/cloudops-gateway/header-tenant-virtualservice.yaml
```

### 4. 验证测试租户命中 canary

```bash
curl -k https://api.cloudops.jianggan.cn/api/v1/version \
  -H "x-tenant-id: test-tenant"

curl -k https://api.cloudops.jianggan.cn/api/v1/version \
  -H "x-canary-user: qa"

curl -k https://api.cloudops.jianggan.cn/api/v1/version \
  -H "x-canary: true"
```

### 5. 验证普通请求仍走 primary

```bash
curl -k https://api.cloudops.jianggan.cn/api/v1/version
```

## 风险与注意事项

```text
1. Header 路由放在 primary 之前，否则不会生效。
2. Header 路由会强制命中 canary service 100%，不受 Argo Rollouts 当前权重限制。
3. 如果 canary service 没有 endpoint，请求可能 503。
4. Header 命名需要和网关 / 前端 / 测试工具统一。
5. 生产租户灰度必须维护租户白名单，避免误命中。
```

## 回退方式

恢复原 VirtualService：

```bash
git checkout -- dev/backend/rollouts/cloudops-gateway/virtualservice.yaml
kubectl apply -f dev/backend/rollouts/cloudops-gateway/virtualservice.yaml
```

或者通过 Argo CD 重新同步：

```bash
kubectl -n argocd annotate application cloudops-gateway-rollout-dev \
  argocd.argoproj.io/refresh=hard \
  --overwrite

kubectl -n argocd patch application cloudops-gateway-rollout-dev \
  --type merge \
  -p '{"operation":{"sync":{"revision":"main","prune":true}}}'
```

## 后续平台化方向

```text
cloudops-cicd 增加灰度租户白名单 API
cloudops-cicd 展示 Header/Tenant 灰度命中规则
Release Record 记录租户灰度范围
与用户/租户系统打通，自动生成灰度白名单
```
