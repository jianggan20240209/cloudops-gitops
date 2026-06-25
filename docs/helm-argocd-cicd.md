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
dev/backend/argocd/application/cloudops-gateway-dev.yaml
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
PATCH /api/v1/applications/<application-name>
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
| `cloudops-gateway` | Go backend | `dev/backend/deployment/go/base` | `cloudops-gateway-dev` | `main-8` |
| `cloudops-web` | UI frontend | `dev/frontend/deployment/ui/base` | `cloudops-web-dev` | `main-7` |

## 9. 后续优化

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
