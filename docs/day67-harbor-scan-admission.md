# Day 67 · Harbor 镜像扫描与发布准入

完整：桌面 `专用测试环境/28_Harbor扫描与发布准入.md`

## Tag 规范

- 构建：`main-<BUILD_NUMBER>`（Kaniko 已用）
- 禁止业务长期依赖 `:latest`
- 环境提升用不可变 digest（后续）

## Harbor

1. 项目 `cloudops` / `library` 开启 **自动扫描**（Trivy）
2. 高危（Critical）策略：lab 先 **告警不阻断**；准入策略文档化后可切阻断
3. 证据：扫描报告截图 / API `GET /projects/{}/repositories/{}/artifacts/{}/additions/vulnerabilities`

## 发布准入（设计）

```text
Jenkins 构建 → Harbor 扫描 →（可选）Kyverno/策略检查 tag+扫描结果
→ Argo sync 仅允许通过策略的 imageTag
```

草案：`dev/platform/security/admission/kyverno-block-latest.yaml`（默认不强制 apply）

**延期**：Kyverno 安装 / Enforce、Harbor UI 自动扫描 — 见 `docs/deferred-week10-security-followups.md`
