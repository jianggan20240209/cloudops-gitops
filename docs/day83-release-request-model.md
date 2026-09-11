# Day 83 · 发布申请模型（Release Request）

训练用数据模型：关联 **Jenkins 构建产物** 与 **GitOps 变更**，供审批字段演练。非强制工作流引擎。

## 字段

| 字段 | 说明 | 示例 |
|------|------|------|
| `request_id` | 申请 ID | `rel-20260912-001` |
| `service` | 服务名 | `cloudops-cicd` |
| `env` | 环境 | `dev` |
| `git_repo` | GitOps 仓 | `cloudops-gitops` |
| `git_revision` | 期望 commit / 分支 tip | `main@abc1234` |
| `image` | 完整镜像 | `harbor-server.jianggan.cn/cloudops/cloudops-cicd:main-17` |
| `jenkins_job` | 构建任务 | `test-cloudops-cicd-kaniko` |
| `jenkins_build_number` | 构建号 | `17` |
| `argo_application` | Argo App | `cloudops-cicd-dev` |
| `change_summary` | 变更摘要 | `fix release record snapshot id` |
| `risk_level` | 风险 | `low` / `medium` / `high` |
| `rollback_plan` | 回滚 | `imageTag 回退上一 succeeded record` |
| `canary` | 是否灰度 | `false` 或 Rollout 名 |
| `approver` | 审批人 | 人工填写 |
| `status` | 状态 | `draft` / `approved` / `shipped` / `aborted` |

## 与现网对象映射

```text
Jenkins build  → image tag + job URL
Harbor         → 制品存在性
Argo CD        → Application sync/health/revision
Release Record → cloudops-cicd POST/GET records（见 helm-argocd-cicd.md）
```

只读查询示例：

```text
GET /api/v1/cicd/apps/{name}/records/latest
GET /api/v1/cicd/apps/{name}/rollback-candidates
```

## 已落地 API（Week 12）

```text
GET/POST /api/v1/cicd/release-requests
GET      /api/v1/cicd/release-requests/{id}
POST     /api/v1/cicd/release-requests/{id}/decide   # approved|rejected
```

CloudOps Web：首页「发布申请」面板。存储：Postgres `release_requests`（与 release_records 同库）或内存降级。

## 审批最小规则（lab）

1. `high` 风险：必须填写 `rollback_plan` + Day 82 清单勾选。  
2. 涉及主入口切流：额外确认 `cloudops-gateway-cutover-*.md`，**先 dry-run**。  
3. 禁止在申请单或 Git 中粘贴密码 / token。

## 相关

- [day82-release-admission-checklist.md](day82-release-admission-checklist.md)  
- [day90-release-risk-and-retro-templates.md](day90-release-risk-and-retro-templates.md)
