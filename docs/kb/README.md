# CloudOps Lab · KB 语料索引

供 RAG / MCP `kb_search` / 诊断 Agent 使用。**禁止**录入密码、Token、私钥。

语料说明：[day120-kb-corpus-index.md](../day120-kb-corpus-index.md)  
RAG 周：[day121-126-week18-rag.md](../day121-126-week18-rag.md)  
选型：桌面 `架构决策/ADR-010-RAG向量库选型.md`

## SOP / 演练

| 文档 | 说明 |
|------|------|
| [day54-network-fault-labs.md](../day54-network-fault-labs.md) | 网络故障三实验 |
| [day61-fault-drill-oom-500-redis.md](../day61-fault-drill-oom-500-redis.md) | OOM / 5xx / Redis |
| [day62-incident-sop.md](../day62-incident-sop.md) | 故障定位 SOP |
| [day113-etcd-backup-sop.md](../day113-etcd-backup-sop.md) | etcd 备份 SOP |
| [day114-velero-install-plan.md](../day114-velero-install-plan.md) | Velero 计划（未默认 apply） |
| [day118-rto-rpo-bc.md](../day118-rto-rpo-bc.md) | RTO/RPO/BC |

## 观测 API

| 文档 | 说明 |
|------|------|
| [day47-cloudops-observe-victorialogs.md](../day47-cloudops-observe-victorialogs.md) | logs API |
| [day59-alertmanager-api-observe.md](../day59-alertmanager-api-observe.md) | alerts API |
| [day60-alert-detail-aggregation.md](../day60-alert-detail-aggregation.md) | alerts detail |
| [day100-resource-api.md](../day100-resource-api.md) | resources API（契约） |
| [day117-backup-api.md](../day117-backup-api.md) | backups API（契约） |
| [day55-observability-ui-jumps.md](../day55-observability-ui-jumps.md) | UI 跳转 |

## 安全 / 发布 / 成本

| 文档 | 说明 |
|------|------|
| [day69-security-boundaries.md](../day69-security-boundaries.md) | AI/Operator/网格边界 |
| [day90-release-risk-and-retro-templates.md](../day90-release-risk-and-retro-templates.md) | 发布风险与复盘 |
| [day97-sidecar-cost-report-template.md](../day97-sidecar-cost-report-template.md) | sidecar 成本 |
| [day82-release-admission-checklist.md](../day82-release-admission-checklist.md) | 发布准入 |

## 资源治理 / 稳定性 / 智能运维

| 文档 | 说明 |
|------|------|
| [day99-resource-profile.md](../day99-resource-profile.md) | 资源画像 |
| [day101-hpa-drill-plan.md](../day101-hpa-drill-plan.md) | HPA 计划 |
| [day103-qos-pdb-priorityclass.md](../day103-qos-pdb-priorityclass.md) | QoS/PDB/Priority |
| [day106-112-week16-chaos-stability.md](../day106-112-week16-chaos-stability.md) | 混沌与稳定性 |
| [day111-stability-system-design.md](../day111-stability-system-design.md) | 稳定性系统设计 |
| [day127-133-week19-mcp.md](../day127-133-week19-mcp.md) | MCP |
| [day134-140-week20-diagnosis-agent.md](../day134-140-week20-diagnosis-agent.md) | 诊断 Agent |
| [day141-147-week21-operator.md](../day141-147-week21-operator.md) | Operator |
| [day148-154-week22-semi-auto-heal.md](../day148-154-week22-semi-auto-heal.md) | 半自动自愈 |

## ADR（桌面目录，勿把密钥写入）

| ADR | 主题 |
|-----|------|
| ADR-001–007 | 底座 / 日志 / OTel / Istio / 安全 / CI-CD / Rollouts |
| ADR-008 | HPA 默认；KEDA 后续；VPA 暂缓 |
| ADR-009 | 轻量故障注入；Chaos Mesh 延期 |
| ADR-010 | SQLite FTS / 本地嵌入；Chroma 可选 |
| ADR-011 | RemediationOperator → Kubebuilder |

路径：`…/Linux运维实战之云原生架构师文档/架构决策/`

## Longhorn

- 作为有状态卷与 Velero/CSI 快照前提，见 [day114](../day114-velero-install-plan.md)、[day118](../day118-rto-rpo-bc.md)；Helm values 中可见 `storageClassName=longhorn`（如 release postgres）。

## Deferred（禁止当「已上线能力」检索）

- [deferred-week15-22-runtime-followups.md](../deferred-week15-22-runtime-followups.md)  
- [deferred-week12-14-runtime-followups.md](../deferred-week12-14-runtime-followups.md)  
- [deferred-week10-security-followups.md](../deferred-week10-security-followups.md)
