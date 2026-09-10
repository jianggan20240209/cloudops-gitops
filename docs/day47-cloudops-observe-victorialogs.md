# Day 47 · cloudops-observe + VictoriaLogs

## 目标

- `cloudops-observe` 封装 VictoriaLogs LogsQL
- `cloudops-web` Pod 日志查询页调用该 API

## API

```text
GET https://cloudops.jianggan.cn/api/v1/observe/logs
  ?namespace=cloudops-dev
  &pod=cloudops-gateway-*
  &container=cloudops-gateway
  &trace_id=day46-trace-001
  &limit=20
```

环境变量：`VICTORIA_LOGS_URL` → `http://vls-victoria-logs-single-server.logging.svc.cluster.local:9428`

## GitOps

| 资源 | 路径 |
|------|------|
| Helm values | `dev/backend/deployment/go/base/values/cloudops-observe.yaml` |
| Argo Application | `dev/backend/argocd/application/cloudops-observe-dev.yaml` |
| Chart env | `templates/deployment.yaml` → `victorialogs.enabled` |

## 上线顺序（需人工确认后执行）

```bash
# 1) 提交并推送（harbor-server）
cd ~/code/cloudops-gitops
git add dev/backend/deployment/go/base/values.yaml \
  dev/backend/deployment/go/base/templates/deployment.yaml \
  dev/backend/deployment/go/base/values/cloudops-observe.yaml \
  dev/backend/argocd/application/cloudops-observe-dev.yaml \
  docs/day47-cloudops-observe-victorialogs.md
git commit -m "feat(observe): add cloudops-observe Helm/Argo for VictoriaLogs"
git push origin main

cd ~/code/cloudops-platform
git add services/cloudops-observe services/cloudops-web \
  Jenkinsfile.cloudops-observe-kaniko
git commit -m "feat(observe): VictoriaLogs LogsQL API and web pod logs page"
git push origin main

# 2) 注册 Argo Application（首次）
kubectl -n argocd apply -f ~/code/cloudops-gitops/dev/backend/argocd/application/cloudops-observe-dev.yaml

# 3) Jenkins：新建 Multibranch/Pipeline 指向 Jenkinsfile.cloudops-observe-kaniko 并构建
#    同时跑一次 cloudops-web Kaniko 发布前端

# 4) 验收
curl -sk 'https://cloudops.jianggan.cn/api/v1/observe/logs?namespace=cloudops-dev&container=cloudops-gateway&trace_id=day46-trace-001&limit=5'
# 浏览器打开 https://cloudops.jianggan.cn/
```

## 验收标准

- [x] `cloudops-observe-dev` Synced / Healthy（2026-09-10）
- [x] `/api/v1/observe/logs` 返回 JSON，`items[].trace_id` 可解析（2026-09-10）
- [x] 首页可按 Pod / trace_id 查出 gateway 日志（2026-09-10）

## 验收记录

- 日期：2026-09-10
- 验证：`curl -sk 'https://cloudops.jianggan.cn/api/v1/observe/logs?namespace=cloudops-dev&container=cloudops-gateway&trace_id=day46-trace-001&limit=5'`
- 结果：返回 `count=2`，日志项已解析出 `trace_id` / `request_id`
- 备注：此前 `ImagePullBackOff` 是因为镜像 tag `main-1` 尚不存在，Jenkins 构建出镜像后恢复正常
