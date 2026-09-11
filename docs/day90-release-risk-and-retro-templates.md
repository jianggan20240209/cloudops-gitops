# Day 90 · 发布风险评估表与复盘模板

## A. 发布风险评估表（每次发版填）

| 项 | 填写 |
|----|------|
| 服务 / 环境 | |
| 镜像 tag | |
| Argo Application | |
| 变更类型 | 配置 / 镜像 / 灰度权重 / 切流 |
| 影响面 | 单服务 / 入口 / 多服务 |
| 风险等级 | low / medium / high |
| 主要风险 | （例：探针过严、Analysis 误杀、切流不可逆） |
| 观测入口 | Grafana / VictoriaLogs / Tempo / Hubble |
| 回滚条件 | （例：5xx>阈值、Analysis Failed、Sync Degraded） |
| 回滚动作 | imageTag 回退 / Rollout abort / Git revert + Sync |
| 审批人 | |
| Day 82 清单 | 已勾选 / 未勾选 |

**高风险必填**：是否触及 `cloudops.jianggan.cn` 主入口；若是，是否已 dry-run（见 cutover 文档）。

---

## B. 发布复盘模板（Markdown）

```markdown
# 发布复盘 · <服务> · <日期>

## 摘要
- 目标：
- 结果：成功 / 部分成功 / 失败回滚
- 时长：

## 变更
- Git revision：
- 镜像：
- Argo Sync/Health：

## 时间线
| 时间 | 事件 |
|------|------|
| | 开始构建 |
| | Sync |
| | 灰度阶段 / Analysis |
| | 完成或 Abort |

## 证据
- Release Record / snapshot：
- 指标 / 日志 / Trace 链接（勿贴密钥）：
- Rollout / AnalysisRun（如有）：

## 根因（若失败）
-

## 改进项
- [ ]
- [ ]

## 是否更新文档 / ADR
- [ ]
```

---

## C. 与平台 API

```text
GET /api/v1/cicd/apps/{name}/records
GET /api/v1/cicd/apps/{name}/records/latest
GET /api/v1/cicd/apps/{name}/rollback-candidates
GET /api/v1/cicd/apps/{name}/rollout
GET /api/v1/cicd/apps/{name}/analysisruns
```

说明见 [helm-argocd-cicd.md](helm-argocd-cicd.md)。
