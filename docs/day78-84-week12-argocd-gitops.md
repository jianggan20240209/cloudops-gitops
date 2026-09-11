# Day 78–84 · 第 12 周索引（Argo CD / GitOps）

桌面复盘：`专用测试环境/33_第12周复盘_Jenkins_Harbor_ArgoCD.md`  
分工 ADR：桌面 `架构决策/ADR-006-Jenkins-Harbor-ArgoCD分工.md`

## 既有资产（优先读这些）

| 主题 | 文档 |
|------|------|
| Helm + Argo 链路 / Release Record / cicd API | [helm-argocd-cicd.md](helm-argocd-cicd.md) |
| 第 11 周构建 API | [day72-76-jenkins-build-apis.md](day72-76-jenkins-build-apis.md) |
| 发布准入 | [day82-release-admission-checklist.md](day82-release-admission-checklist.md) |
| 发布申请模型 | [day83-release-request-model.md](day83-release-request-model.md) |
| 周复盘摘要 | [day84-week12-retro.md](day84-week12-retro.md) |

## Day 映射

| Day | 交付 | 状态 |
|-----|------|------|
| 78 | Argo CD 已部署并接 Git | ✅（历史落地，见 helm 文档） |
| 79 | Helm chart + values / imageTag | ✅ |
| 80 | Sync / Diff / Rollback / 漂移 | ✅ |
| 81 | CloudOps Argo/Release 状态 | ✅ |
| 82 | 准入清单 | ✅ 本文档集 |
| 83 | 发布申请模型 | ✅ |
| 84 | 复盘 + ADR-006 | ✅ |

## 延期

破坏性运行时项 → [deferred-week12-14-runtime-followups.md](deferred-week12-14-runtime-followups.md)
