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

本实验只提供 Runbook 和示例清单，不自动修改当前生效的 `cloudops-gateway-rollout`。

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

这些示例不在 Argo CD Application 路径下，不会自动生效。正式应用前需要结合当前 Rollout 和 VirtualService 状态进行人工评审。

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

### 2. 应用 timeout/retry 示例

```bash
kubectl apply -f docs/examples/cloudops-gateway/traffic-policy/virtualservice-timeout-retry.yaml
```

验证：

```bash
kubectl -n cloudops-dev get virtualservice cloudops-gateway-rollout -o yaml | grep -A10 'timeout:'

curl -k https://api.cloudops.jianggan.cn/readyz
curl -k https://api.cloudops.jianggan.cn/api/v1/version
```

### 3. 应用 circuit breaker 示例

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

恢复 GitOps 中当前 VirtualService：

```bash
kubectl apply -f dev/backend/rollouts/cloudops-gateway/virtualservice.yaml
```

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
将 timeout/retry/circuit breaker 参数纳入 values 管理
Release Record 记录流量治理策略版本
故障复盘时关联 Istio 指标与灰度阶段
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
