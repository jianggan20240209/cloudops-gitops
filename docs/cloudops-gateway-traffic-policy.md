# cloudops-gateway Istio 流量治理实验

## 目标

在 `cloudops-gateway-rollout` 已完成 Argo Rollouts + Istio 精确灰度的基础上，补充 Istio 流量治理能力实验：

```text
timeout
retry
circuit breaker
outlier detection
connection pool
```

本实验提供 Runbook、示例清单，以及通过 Helm values 正式启用流量治理的方式。

## GitOps 流量治理配置

`cloudops-gateway-rollout` 已迁移到共享 Helm chart，流量治理参数通过 values 管理：

```text
dev/backend/rollouts/chart/                  # 共享 istio-rollout chart
dev/backend/rollouts/chart/values/cloudops-gateway.yaml
dev/backend/argocd/application/cloudops-gateway-rollout-dev.yaml
```

关键 values 段：

```yaml
trafficPolicy:
  timeoutRetry:
    enabled: false
    timeout: 3s
    retries:
      attempts: 2
      perTryTimeout: 1s
      retryOn: connect-failure,refused-stream,5xx
  circuitBreaker:
    enabled: false
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 100
        maxRequestsPerConnection: 10
    outlierDetection:
      consecutive5xxErrors: 5
      interval: 30s
      baseEjectionTime: 60s
      maxEjectionPercent: 50
```

默认 `enabled: false`，不改变当前运行态。评审通过后修改 values 并 push，由 Argo CD 自动同步。

启用 timeout/retry：

```yaml
trafficPolicy:
  timeoutRetry:
    enabled: true
```

启用 circuit breaker：

```yaml
trafficPolicy:
  circuitBreaker:
    enabled: true
```

Argo CD Application 已配置 `ignoreDifferences`，避免 Rollout 调整 VirtualService 权重时被 GitOps 回滚。

## 适用场景

```text
接口偶发 5xx
后端实例不稳定
连接数过高
请求超时
灰度阶段需要限制爆炸半径
```

## 示例清单

```text
docs/examples/cloudops-gateway/traffic-policy/virtualservice-timeout-retry.yaml
docs/examples/cloudops-gateway/traffic-policy/destinationrule-circuit-breaker.yaml
```

这些示例用于手工演练参考。正式环境请优先修改 `dev/backend/rollouts/chart/values/cloudops-gateway.yaml` 中的 `trafficPolicy` 段。

## Timeout / Retry 策略

建议从保守配置开始：

```text
timeout: 3s
attempts: 2
perTryTimeout: 1s
retryOn: connect-failure,refused-stream,5xx
```

含义：

```text
单个请求总超时 3 秒
最多尝试 2 次
每次尝试最多 1 秒
只对连接失败、拒绝流、5xx 进行重试
```

注意：

```text
不要盲目增加重试次数。
重试会放大下游压力，特别是在故障期间。
```

## Circuit Breaker / Outlier Detection

建议初始配置：

```text
connectionPool.tcp.maxConnections: 100
connectionPool.http.http1MaxPendingRequests: 100
connectionPool.http.maxRequestsPerConnection: 10
outlierDetection.consecutive5xxErrors: 5
outlierDetection.interval: 30s
outlierDetection.baseEjectionTime: 60s
outlierDetection.maxEjectionPercent: 50
```

含义：

```text
限制连接池和待处理请求数量
连续 5 次 5xx 后进行异常实例驱逐
每 30 秒检测一次
驱逐 60 秒
最多驱逐 50% 实例
```

## 演练步骤

### 1. 确认当前服务健康

```bash
curl -k https://api.cloudops.jianggan.cn/readyz
curl -k https://api.cloudops.jianggan.cn/api/v1/version

kubectl -n cloudops-dev get rollout cloudops-gateway-rollout
kubectl -n cloudops-dev get virtualservice cloudops-gateway-rollout -o yaml | grep -A30 'http:'
```

### 2. 通过 values 启用 timeout/retry（推荐）

编辑 `dev/backend/rollouts/chart/values/cloudops-gateway.yaml`：

```yaml
trafficPolicy:
  timeoutRetry:
    enabled: true
```

提交并 push 后，Argo CD 会自动同步 VirtualService。

验证：

```bash
helm template cloudops-gateway-rollout dev/backend/rollouts/chart \
  -f dev/backend/rollouts/chart/values/cloudops-gateway.yaml \
  --set trafficPolicy.timeoutRetry.enabled=true | grep -A6 'timeout:'

kubectl -n cloudops-dev get virtualservice cloudops-gateway-rollout -o yaml | grep -A10 'timeout:'

curl -k https://api.cloudops.jianggan.cn/readyz
curl -k https://api.cloudops.jianggan.cn/api/v1/version
```

### 2b. 手工应用 timeout/retry 示例（仅演练）

```bash
kubectl apply -f docs/examples/cloudops-gateway/traffic-policy/virtualservice-timeout-retry.yaml
```

验证：

```bash
kubectl -n cloudops-dev get virtualservice cloudops-gateway-rollout -o yaml | grep -A10 'timeout:'

curl -k https://api.cloudops.jianggan.cn/readyz
curl -k https://api.cloudops.jianggan.cn/api/v1/version
```

### 3. 通过 values 启用 circuit breaker（推荐）

编辑 `dev/backend/rollouts/chart/values/cloudops-gateway.yaml`：

```yaml
trafficPolicy:
  circuitBreaker:
    enabled: true
```

提交并 push 后，Argo CD 会自动创建 DestinationRule。

验证：

```bash
kubectl -n cloudops-dev get destinationrule cloudops-gateway-rollout cloudops-gateway-rollout-canary
```

### 3b. 手工应用 circuit breaker 示例（仅演练）

```bash
kubectl apply -f docs/examples/cloudops-gateway/traffic-policy/destinationrule-circuit-breaker.yaml
```

验证：

```bash
kubectl -n cloudops-dev get destinationrule cloudops-gateway-rollout cloudops-gateway-rollout-canary
```

### 4. 观察指标

```bash
kubectl -n monitoring run curl-prom-istio-gateway-query \
  --rm -i --restart=Never \
  --image=curlimages/curl:8.16.0 \
  -- curl -s 'http://kube-prometheus-stack-prometheus:9090/api/v1/query?query=sum(rate(istio_requests_total%7Bdestination_service_name%3D~%22cloudops-gateway-rollout-.*%22%7D%5B5m%5D))'
```

可关注：

```text
istio_requests_total
istio_request_duration_milliseconds
istio_tcp_connections_opened_total
istio_tcp_connections_closed_total
```

## 回退方式

通过 values 关闭流量治理：

```yaml
trafficPolicy:
  timeoutRetry:
    enabled: false
  circuitBreaker:
    enabled: false
```

提交并 push 后由 Argo CD 同步。或手工恢复：

删除 DestinationRule：

```bash
kubectl -n cloudops-dev delete destinationrule cloudops-gateway-rollout --ignore-not-found
kubectl -n cloudops-dev delete destinationrule cloudops-gateway-rollout-canary --ignore-not-found
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

## Go / No-Go

Go：

```text
readyz 正常
version 正常
Rollout Healthy
Prometheus target healthy
无异常 5xx
```

No-Go：

```text
API 超时增加
5xx 增加
Rollout 非 Healthy
Istio 指标异常
```

## 后续平台化方向

```text
将 timeout/retry/circuit breaker 参数纳入 values 管理   # 已完成
Release Record 记录流量治理策略版本                      # 已完成
故障复盘时关联 Istio 指标与灰度阶段                      # 已完成（cloudops-cicd /observability）
```

## Helm 迁移验证

在可访问集群的环境执行：

```bash
bash scripts/verify-cloudops-gateway-rollout-helm.sh
```

### 2026-06-29 首次验证结果

```text
Argo CD: OutOfSync / Healthy
revision: eeebadb
spec.source.path: dev/backend/rollouts/cloudops-gateway   # 仍是旧 plain 目录
spec.source.helm.valueFiles: <none>

VirtualService: 仅有 weight 100/0，无 timeout/retry
API: readyz / version 正常
cloudops-cicd /traffic: 无 timeout/retry 字段
```

结论：Git 仓库已切到 Helm chart，但 Argo CD 无法加载 chart 目录外的 `../cloudops-gateway/values.yaml`，实际仍使用 chart 默认 values（timeoutRetry 关闭）。values 已移入 `chart/values/cloudops-gateway.yaml`。

修复步骤：

```bash
git pull
kubectl apply -f dev/backend/argocd/application/cloudops-gateway-rollout-dev.yaml

kubectl -n argocd annotate application cloudops-gateway-rollout-dev \
  argocd.argoproj.io/refresh=hard --overwrite

kubectl -n argocd patch application cloudops-gateway-rollout-dev \
  --type merge \
  -p '{"operation":{"sync":{"revision":"main","prune":true}}}'

# 若仍 OutOfSync，查看原因：
kubectl -n argocd get application cloudops-gateway-rollout-dev \
  -o jsonpath='{.status.operationState.phase}{" "}{.status.operationState.message}{"\n"}'

bash scripts/verify-cloudops-gateway-rollout-helm.sh
```

同步成功后预期：

```text
spec.source.path: dev/backend/rollouts/chart
spec.source.helm.valueFiles: values/cloudops-gateway.yaml
Argo CD: Synced / Healthy
VirtualService: timeout=3s, retries.attempts=2
cloudops-cicd /traffic 显示 timeout/retry
```

### 2026-06-29 修复后验证结果

```text
git pull: a890285
Argo CD: Synced / Healthy
revision: 5c06d9b
Helm path: dev/backend/rollouts/chart
Helm valueFiles: values/cloudops-gateway.yaml

VirtualService:
  timeout: 3s
  retries.attempts: 2
  retries.perTryTimeout: 1s
  retries.retryOn: connect-failure,refused-stream,5xx
  stable weight: 100
  canary weight: 0

API:
  readyz: ok
  version: main-13

cloudops-cicd /traffic:
  timeout: 3s
  retries: attempts=2, per_try_timeout=1s

待完成:
  cloudops-cicd /observability 返回 404
  需运行 Jenkins test-cloudops-cicd-kaniko 部署 v13 镜像
```

### 2026-06-29 observability 部署验证结果

```text
cloudops-cicd 镜像: main-17
Argo CD cloudops-cicd-dev: Synced / Healthy

GET /api/v1/cicd/apps/cloudops-gateway-rollout/observability:
  canary_stage:
    phase: Healthy
    current_step_index: 7
    stable_weight: 100
    stage: stable
  istio_metrics:
    source: prometheus
    message: no istio request metrics matched destination_service_name=~"cloudops-gateway-rollout-.*"
  source: kubernetes,prometheus

verify-cloudops-gateway-rollout-helm.sh: 全部 PASS
```

说明：`istio_metrics` 暂无数据通常是因为 Prometheus 中 `destination_service_name` 标签与查询不匹配，或近期无经 Istio 的 API 流量。可在产生流量后重试，或后续调整 PromQL 标签匹配。

`/observability` 已随 Jenkins `test-cloudops-cicd-kaniko` 部署 main-17 生效。

检查项：

```text
Argo CD Application: Synced / Healthy
Helm source: dev/backend/rollouts/chart + values.yaml
VirtualService: timeout/retry 已启用（trafficPolicy.timeoutRetry.enabled=true）
API readyz / version 正常
cloudops-cicd /traffic 返回 timeout/retry 摘要
```

## cloudops-cicd 流量策略查询

`cloudops-cicd` 已提供 Istio 流量治理摘要接口：

```bash
curl --ssl-no-revoke -k https://cloudops.jianggan.cn/api/v1/cicd/apps/cloudops-gateway-rollout/traffic
```

返回内容包括：

```text
VirtualService:
  hosts
  gateways
  route host / port / weight
  timeout
  retries

DestinationRule:
  host
  connectionPool
  outlierDetection
```

该接口用于发布评审和故障复盘时确认当前流量治理策略。

实际验证结果：

```text
验证时间: 2026-06-28
验证接口:
  GET /api/v1/cicd/apps/cloudops-gateway-rollout/traffic

VirtualService:
  name: cloudops-gateway-rollout
  namespace: cloudops-dev
  hosts:
    - istio-cloudops-gateway.jianggan.cn
    - api.cloudops.jianggan.cn
  gateways:
    - cloudops-gateway-rollout
  route:
    cloudops-gateway-rollout-stable:
      port: 80
      weight: 100
    cloudops-gateway-rollout-canary:
      port: 80
      weight: 0

DestinationRule:
  当前未应用运行态 DestinationRule，因此返回为空。
```

## Release Record 策略记录设计

`/traffic` 摘要已接入 Release Record snapshot，用于审计一次发布期间的流量治理策略。

建议记录字段：

```text
traffic.virtual_service.hosts
traffic.virtual_service.gateways
traffic.virtual_service.routes[].host
traffic.virtual_service.routes[].weight
traffic.virtual_service.routes[].timeout
traffic.virtual_service.routes[].retries
traffic.destination_rules[].host
traffic.destination_rules[].connection_pool
traffic.destination_rules[].outlier_detection
```

记录时机：

```text
发布前:
  记录当前 stable/canary 权重和是否启用 timeout/retry/circuit breaker

灰度中:
  记录 25% / 50% 阶段的 VirtualService 权重

发布后:
  记录 stable 100 / canary 0 的最终状态

故障时:
  记录故障发生时的 timeout/retry/circuit breaker 和 outlier detection 状态
```

价值：

```text
发布复盘时能确认当时实际流量权重
能判断是否存在重试放大故障
能判断是否启用熔断和异常实例剔除
能把流量策略和 AnalysisRun / Prometheus 指标关联
```

保存方式：

```bash
curl --ssl-no-revoke -k -X POST \
  https://cloudops.jianggan.cn/api/v1/cicd/apps/cloudops-gateway-rollout/records/snapshot
```

快照中的 `verification.traffic` 会保存当前 VirtualService 和 DestinationRule 摘要。
快照中的 `verification.observability` 会保存灰度阶段与 Istio 指标关联结果。

## 故障复盘关联

`cloudops-cicd` 提供 observability 接口，将灰度阶段与 Istio 指标关联：

```bash
curl --ssl-no-revoke -k https://cloudops.jianggan.cn/api/v1/cicd/apps/cloudops-gateway-rollout/observability
```

返回字段：

```text
canary_stage.phase
canary_stage.current_step_index
canary_stage.stable_weight
canary_stage.canary_weight
canary_stage.stage                # stable / canary_25 / canary_50 / progressing

istio_metrics.request_rate_rps
istio_metrics.error_rate_rps
istio_metrics.error_rate_percent
istio_metrics.p95_latency_ms
istio_metrics.by_destination[]    # stable / canary 拆分
```

复盘时建议：

```text
1. 保存灰度前 / 25% / 50% / 100% 各阶段 snapshot
2. 对比 observability.canary_stage.stage 与 istio_metrics.error_rate_percent
3. 若启用 timeout/retry，检查 error 是否因重试放大
4. 若启用 circuit breaker，检查 by_destination 是否出现 stable/canary 差异
```

保存 snapshot：

```bash
curl --ssl-no-revoke -k -X POST \
  https://cloudops.jianggan.cn/api/v1/cicd/apps/cloudops-gateway-rollout/records/snapshot
```
