# Day 82 · 发布准入清单（Release Admission Checklist）

用途：每次实验室发版前人工勾选。不替代 Kyverno/Harbor 强制门禁（强制项见第 10 周延期文档）。

## 1. 镜像与制品

- [ ] 镜像来自 Harbor：`harbor-server.jianggan.cn/cloudops/<svc>:main-<BUILD_NUMBER>`
- [ ] tag **不是** `:latest`
- [ ] Jenkins 构建 SUCCESS；失败通知含构建链接（第 11 周约定）
- [ ] （可选）Harbor 扫描结果已人工查看——**自动扫描开关延期**见 `deferred-week10-security-followups.md`

## 2. 配置与 GitOps

- [ ] 变更在 Git（values / Application），无「仅集群手改」残留
- [ ] `app.imageTag` 与 Harbor tag 一致
- [ ] Secret 仅集群 Secret，**未**写入 Git
- [ ] harbor-server / 工作树已 `git pull` 对齐

## 3. 资源与健康

- [ ] requests/limits 合理（无无限内存）
- [ ] readiness/liveness 仍有效；新版本探针未误伤
- [ ] Argo Application 目标 ns 正确（如 `cloudops-dev`）

## 4. 回滚与灰度

- [ ] 已知上一成功 Release Record / rollback-candidates
- [ ] 若走 Rollout：独立域名或并行 Application，**不误伤**主入口除非已确认切流
- [ ] Analysis / 观测入口已知（Prometheus / Grafana / VictoriaLogs）

## 5. 发布后验收（示例，无密钥）

```bash
kubectl -n argocd get application <app>-dev
curl -sk https://cloudops.jianggan.cn/api/v1/cicd/apps/<app>/records/latest
```

## 相关

- 分工 ADR：桌面 `架构决策/ADR-006-Jenkins-Harbor-ArgoCD分工.md`
- 链路说明：[helm-argocd-cicd.md](helm-argocd-cicd.md)
