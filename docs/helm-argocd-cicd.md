# Helm + Argo CD CI/CD 说明

## 1. 目标

CloudOps 应用部署统一改为 Helm chart + values 文件方式管理。

CI/CD 目标链路：

```text
开发提交代码
-> Jenkins 拉取 cloudops-platform
-> Kaniko 构建镜像
-> 镜像 tag 使用 main-${BUILD_NUMBER}
-> 推送到 Harbor
-> Jenkins 调用 Argo CD API 更新 Helm 参数 app.imageTag
-> Jenkins 调用 Argo CD API 触发应用同步
-> Jenkins 轮询 Argo CD Application 状态
-> Synced / Healthy 后流水线成功
```

## 2. GitOps 目录规范

目录按环境、前后端、应用类型拆分：

```text
dev/
  backend/
    argocd/
      application/
      project/
    deployment/
      go/
        base/
          templates/
          values/
      python/
        base/
          templates/
          values/
  frontend/
    argocd/
      application/
      project/
    deployment/
      node/
        base/
          templates/
          values/
      ui/
        base/
          templates/
          values/
prod/
  backend/
  frontend/
```

当前已经接入：

```text
dev/backend/deployment/go/base
dev/backend/deployment/go/base/values/cloudops-gateway.yaml
dev/backend/deployment/go/base/values/cloudops-cicd.yaml
dev/backend/argocd/application/cloudops-gateway-dev.yaml
dev/backend/argocd/application/cloudops-cicd-dev.yaml
dev/backend/argocd/project/dev-backend-project.yaml

dev/frontend/deployment/ui/base
dev/frontend/deployment/ui/base/values/cloudops-web.yaml
dev/frontend/argocd/application/cloudops-web-dev.yaml
dev/frontend/argocd/project/dev-frontend-project.yaml
```

## 3. values 参数规范

应用 values 文件统一包含：

```yaml
base:
  envName: dev
  namespace: cloudops-dev

app:
  serviceName: cloudops-gateway
  servicePort: 80
  imageTag: main-8
  replicas: 2

service:
  targetPort: 8080
  type: ClusterIP
```

字段说明：

```text
base.envName:
  环境名称，当前支持 dev / prod。

base.namespace:
  Kubernetes 命名空间，dev 对应 cloudops-dev，prod 对应 cloudops-prod。

app.serviceName:
  服务名称，同时作为 Deployment / Service / Ingress / ServiceMonitor 的名称。

app.servicePort:
  Kubernetes Service 对外暴露端口，也是 Ingress backend 引用的 Service 端口。

app.imageTag:
  镜像 tag，由 Jenkins BUILD_NUMBER 生成，例如 main-8、main-9。

app.replicas:
  Deployment 副本数。

service.targetPort:
  容器端口，即 containerPort。

service.type:
  Kubernetes Service 类型，例如 ClusterIP、NodePort。
```

## 4. Helm base chart

### 4.1 Go backend base

路径：

```text
dev/backend/deployment/go/base
```

包含：

```text
Chart.yaml
values.yaml
templates/_helpers.tpl
templates/deployment.yaml
templates/service.yaml
templates/ingress.yaml
templates/servicemonitor.yaml
values/cloudops-gateway.yaml
```

适用：

```text
Go HTTP API 服务
暴露 /healthz、/readyz、/metrics
需要 Ingress /api 路由
需要 Prometheus ServiceMonitor
```

### 4.2 UI frontend base

路径：

```text
dev/frontend/deployment/ui/base
```

包含：

```text
Chart.yaml
values.yaml
templates/_helpers.tpl
templates/deployment.yaml
templates/service.yaml
templates/ingress.yaml
values/cloudops-web.yaml
```

适用：

```text
前端 UI 服务
通过 cloudops.jianggan.cn / 路径访问
```

## 5. Argo CD 配置

### 5.1 AppProject

dev backend：

```text
dev/backend/argocd/project/dev-backend-project.yaml
```

dev frontend：

```text
dev/frontend/argocd/project/dev-frontend-project.yaml
```

### 5.2 Application

cloudops-gateway：

```text
dev/backend/argocd/application/cloudops-gateway-dev.yaml
```

关键配置：

```yaml
spec:
  project: dev-backend
  source:
    repoURL: https://github.com/jianggan20240209/cloudops-gitops.git
    targetRevision: main
    path: dev/backend/deployment/go/base
    helm:
      valueFiles:
        - values/cloudops-gateway.yaml
      parameters:
        - name: app.imageTag
          value: main-8
          forceString: true
```

cloudops-web：

```text
dev/frontend/argocd/application/cloudops-web-dev.yaml
```

## 6. Jenkins 凭据要求

需要以下 Jenkins 凭据：

```text
github-user:
  类型: Username with password / GitHub token
  用途: 拉取 cloudops-platform 仓库

harbor-pull-secret:
  类型: Kubernetes Secret
  命名空间: devops
  用途: Kaniko 推送镜像到 Harbor

jianggan-root-ca:
  类型: Kubernetes Secret
  命名空间: devops
  用途: Kaniko 信任 Harbor HTTPS 证书

argocd-auth-token:
  类型: Secret text
  用途: Jenkins 调用 Argo CD API

cloudops-cicd-harbor-credential:
  类型: Kubernetes Secret
  命名空间: cloudops-dev
  用途: cloudops-cicd 查询 Harbor 镜像 tag
  字段:
    username
    password
```

`argocd-auth-token` 应使用 Argo CD 账号生成的 API token。

## 7. Jenkinsfile 行为

### 7.1 镜像 tag

镜像 tag 统一使用：

```text
main-${BUILD_NUMBER}
```

示例：

```text
harbor-server.jianggan.cn/cloudops/cloudops-gateway:main-9
harbor-server.jianggan.cn/cloudops/cloudops-web:main-8
```

不再依赖 `latest` 触发发布。

### 7.2 Argo CD API 更新 Helm 参数

Jenkins 构建镜像成功后，调用：

```text
PUT /api/v1/applications/<application-name>
```

更新 Helm 参数：

```text
app.imageTag = main-${BUILD_NUMBER}
```

然后调用：

```text
POST /api/v1/applications/<application-name>/sync
```

触发同步。

注意：

```text
不要使用 Content-Type: application/merge-patch+json。
当前验证可用方式是使用 Content-Type: application/json，并提交完整 Application 结构。
curl 必须加 -f，确保 Argo CD API 返回非 2xx 时流水线失败。
```

### 7.3 轮询发布结果

Jenkins 每 5 秒查询一次：

```text
GET /api/v1/applications/<application-name>
```

成功条件：

```text
sync.status = Synced
health.status = Healthy
```

失败条件：

```text
operationState.phase = Failed
operationState.phase = Error
```

超时仍未成功时，流水线失败。

## 8. 当前应用映射

| 应用 | 类型 | Helm base | Argo CD Application | 当前镜像 tag |
|---|---|---|---|---|
| `cloudops-gateway` | Go backend | `dev/backend/deployment/go/base` | `cloudops-gateway-dev` | `main-14` |
| `cloudops-cicd` | Go backend | `dev/backend/deployment/go/base` | `cloudops-cicd-dev` | `main-3` |
| `cloudops-web` | UI frontend | `dev/frontend/deployment/ui/base` | `cloudops-web-dev` | `main-8` |

## 9. 已验证结果

### 9.1 cloudops-gateway

已验证：

```text
Jenkins BUILD_NUMBER: 14
Image: harbor-server.jianggan.cn/cloudops/cloudops-gateway:main-14
Argo CD Application: cloudops-gateway-dev
Helm parameter: app.imageTag=main-14
Deployment image: harbor-server.jianggan.cn/cloudops/cloudops-gateway:main-14
Service endpoint: https://cloudops.jianggan.cn/api/v1/version
Service version: main-14
Commit: c308075261dc
Argo CD status: Synced / Healthy
```

### 9.2 cloudops-web

已验证：

```text
Image: harbor-server.jianggan.cn/cloudops/cloudops-web:main-8
Argo CD Application: cloudops-web-dev
Helm parameter: app.imageTag=main-8
Argo CD status: Synced / Healthy
Service endpoint: https://cloudops.jianggan.cn/
```

### 9.3 cloudops-cicd

第二版已接入 Argo CD API 实时状态：

```text
Jenkins: test-cloudops-cicd-kaniko #1 SUCCESS
Image: harbor-server.jianggan.cn/cloudops/cloudops-cicd:main-3
Argo CD Application: cloudops-cicd-dev
Helm base: dev/backend/deployment/go/base
Helm values: values/cloudops-cicd.yaml
Deployment image: harbor-server.jianggan.cn/cloudops/cloudops-cicd:main-3
Service endpoint: https://cloudops.jianggan.cn/api/v1/cicd/apps
Metrics: cloudops_cicd_info
Argo CD status: Synced / Healthy
Data source: argocd
```

第一版接口：

```text
GET /api/v1/cicd/apps
GET /api/v1/cicd/apps/{name}
GET /api/v1/cicd/apps/{name}/status
GET /api/v1/cicd/apps/{name}/releases
GET /api/v1/cicd/apps/{name}/images
```

已验证接口：

```text
GET /api/v1/cicd/apps
GET /api/v1/cicd/apps/cloudops-gateway
GET /api/v1/cicd/apps/cloudops-gateway/status
```

第三版新增 Harbor 镜像 tag 查询：

```text
GET /api/v1/cicd/apps/cloudops-gateway/images
GET /api/v1/cicd/apps/cloudops-web/images
GET /api/v1/cicd/apps/cloudops-cicd/images
```

未配置 Harbor 凭据或查询失败时，接口会回退静态发布历史，并返回 `source=static` 和 `warning`。

实时返回应用：

```text
cloudops-gateway: main-14 / Synced / Healthy / source=argocd
cloudops-web: main-8 / Synced / Healthy / source=argocd
cloudops-cicd: main-3 / Synced / Healthy / source=argocd
```

注意：`cloudops-cicd-argocd-token` 曾在对话中暴露，建议后续重新生成 Argo CD token 并轮换该 Secret。

### 9.4 最终状态检查

最终检查命令：

```bash
kubectl -n argocd get application cloudops-gateway-dev cloudops-web-dev

kubectl -n cloudops-dev get deploy cloudops-gateway cloudops-web \
  -o custom-columns=NAME:.metadata.name,IMAGE:.spec.template.spec.containers[0].image

curl --ssl-no-revoke -k https://cloudops.jianggan.cn/api/v1/version
curl --ssl-no-revoke -k https://cloudops.jianggan.cn/
```

最终结果：

```text
cloudops-gateway-dev   Synced   Healthy
cloudops-web-dev       Synced   Healthy

cloudops-gateway   harbor-server.jianggan.cn/cloudops/cloudops-gateway:main-14
cloudops-web       harbor-server.jianggan.cn/cloudops/cloudops-web:main-8

cloudops-gateway /api/v1/version 返回 version=main-14
cloudops-web / 返回前端 HTML 页面
```

### 9.5 排障记录

本次 Jenkins + Argo CD API 发布链路中遇到并修复了以下问题：

```text
1. Declarative Pipeline 默认 Checkout 早于代理配置执行。
   修复: 增加 skipDefaultCheckout(true)，改用显式 Checkout 阶段。

2. Kaniko 容器内没有 git 命令。
   修复: 在 jnlp 容器生成 gateway-build.env，再在 kaniko 容器读取。

3. curl sidecar 容器无法启动 Jenkins durable task。
   修复: curl 容器使用 command: cat、tty: true、runAsUser: 0，并挂载 workspace-volume。

4. PATCH application/merge-patch+json 返回 Invalid content type。
   修复: 改用 PUT /api/v1/applications/<app>，Content-Type: application/json，提交完整 Application body。

5. 校验 imageTag 时误抓 status.history 中的旧 tag。
   修复: 只校验顶层 spec 部分是否包含当前 IMAGE_TAG，避免被历史字段干扰。
```

## 10. 后续优化

后续建议：

```text
将 Argo CD API 调用封装为共享 Jenkins Library
为不同环境增加 prod values
接入 Argo Rollouts 实现灰度发布
增加镜像安全扫描
增加构建产物 SBOM
增加发布审计记录
将 imageTag 参数变更回写 GitOps 仓库，形成完全 GitOps 审计链
```
