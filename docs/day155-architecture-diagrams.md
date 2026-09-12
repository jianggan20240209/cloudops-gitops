# Day 155 · CloudOps AI 平台架构图集

日期：2026-09-12  
对齐：训练计划第 23 周 Day 155；桌面副本 `专用测试环境/44_第23周_架构图集.md`  
用途：作品集 / 面试白板 / 10 分钟讲解开场

> 图中域名为 lab：`*.jianggan.cn`。延期运行时项（Falco 安装、Chaos live、STRICT mTLS 等）**不画成已上线能力**。

---

## 1. 实验室物理与逻辑拓扑

```mermaid
flowchart TB
  subgraph LAN["家庭 LAN 192.168.1.0/24"]
    PC["运维 PC<br/>编辑 + Git"]
    T430["Dell T430 · Proxmox 192.168.1.100"]
    HS["harbor-server 192.168.1.200<br/>Ubuntu / VMware on laptop"]
  end

  subgraph PVE["PVE 上的 K8s 虚机"]
    M["masters ×3"]
    N["nodes ×N"]
  end

  subgraph HS_SVCS["harbor-server 上的平台侧服务"]
    Harbor["Harbor"]
    Rancher["Rancher"]
    Tiny["tinyproxy :8888"]
    VPN["OpenVPN client"]
    Kubectl["kubectl admin"]
  end

  PC -->|Samba / 本地仓库| HS
  PC -->|HTTPS Ingress| ING
  T430 --> PVE
  HS --> HS_SVCS
  Kubectl --> PVE
  Harbor -->|镜像拉取| PVE

  subgraph CLUSTER["Kubernetes 集群"]
    ING["Ingress NGINX"]
    COPS["cloudops-dev"]
    OBS["monitoring / logging / tracing"]
    CICD["cicd · Jenkins/Argo 相关"]
  end

  PVE --> CLUSTER
```

**一句话**：计算与控制面在 T430/PVE；制品与运维跳板在 `harbor-server`；业务与可观测跑在 K8s。

---

## 2. CloudOps 平台模块图

```mermaid
flowchart LR
  User["浏览器"] --> Web["cloudops-web<br/>左侧分类控制台"]
  Web --> GW["cloudops-gateway"]

  GW --> K8S["cloudops-k8s-manager"]
  GW --> OBSV["cloudops-observe"]
  GW --> CICD["cloudops-cicd"]
  GW --> AI["cloudops-aiops"]

  K8S --> API["K8s API"]
  OBSV --> Prom["Prometheus"]
  OBSV --> VL["VictoriaLogs"]
  OBSV --> AM["Alertmanager"]
  OBSV --> Tempo["Tempo"]
  CICD --> J["Jenkins"]
  CICD --> Argo["Argo CD API"]
  AI --> KB["本地 RAG / KB"]
  AI --> Tools["只读工具：K8s/Prom/VL/Tempo/CI"]
  AI -.->|建议，不直接执行| Rem["Remediation CRD<br/>审批后 Operator"]
```

| 模块 | 职责 |
|------|------|
| web | 可观测 / 交付 / FinOps / AIOps 工作区 |
| gateway | 统一 API 前缀、鉴权占位、路由 |
| k8s-manager | Namespace/Pod/Node/Event 只读查询 |
| observe | 指标、日志、告警、资源浪费、备份任务契约 |
| cicd | Jenkins 构建、Argo 状态、发布申请 |
| aiops | `/ask` `/diagnose` `/tools` `/remediation/suggest` `/retro/draft` |

---

## 3. 北向流量与部署图

```mermaid
flowchart TB
  U["User / HTTPS"] --> DNS["*.jianggan.cn"]
  DNS --> ING["Ingress NGINX"]
  ING --> WEB["cloudops-web"]
  ING --> GW["cloudops-gateway"]
  ING --> GRAF["Grafana"]
  ING --> ARGOUI["Argo CD UI"]
  ING --> JEN["Jenkins"]

  GW --> SVC["ClusterIP Services<br/>observe / cicd / k8s / aiops"]

  subgraph GitOps["GitOps"]
    GH["GitHub: cloudops-platform / cloudops-gitops"]
    AC["Argo CD Applications"]
    Helm["Helm values · imageTag"]
  end

  GH --> AC --> Helm --> DEP["Deployments / Rollouts in cloudops-dev"]
```

**边界（ADR-004）**：基础设施（监控、Harbor、Jenkins）**不进 Istio mesh**；业务/demo 按需注入。N-S 灰度与 Gateway/VS 已具备；真 E-W sidecar 金丝雀见延期清单。

---

## 4. 可观测管道图

```mermaid
flowchart LR
  APP["cloudops / demo Pods"] --> Beyla["Beyla eBPF"]
  APP --> Metrics["/metrics"]
  APP --> Logs["stdout JSON + trace_id"]

  Beyla -->|OTLP| Col["OTel Collector"]
  Metrics --> Prom["Prometheus"]
  Logs --> Alloy["Alloy"] --> VL["VictoriaLogs"]
  Col --> Tempo["Tempo"]

  Prom --> Graf["Grafana"]
  VL --> Graf
  Tempo --> Graf
  Cilium["Cilium"] --> Hubble["Hubble"]

  Prom --> AM["Alertmanager"]
  AM --> Observe["cloudops-observe"]
  VL --> Observe
  Prom --> Observe
  Tempo --> Observe

  Observe --> UI["CloudOps 告警 / 日志 / 观测入口"]
```

主线：**Beyla + 少量 OTel SDK + Collector + Tempo**；日志 **Alloy → VictoriaLogs**（ADR-002/003）。

---

## 5. 发布治理链路图

```mermaid
sequenceDiagram
  participant Dev as 开发/运维
  participant Web as CloudOps Web
  participant Cicd as cloudops-cicd
  participant Jen as Jenkins
  participant Har as Harbor
  participant Git as cloudops-gitops
  participant Argo as Argo CD
  participant Clu as cloudops-dev

  Dev->>Web: 批量构建 / 发布申请
  Web->>Cicd: API
  Cicd->>Jen: 触发 job
  Jen->>Har: 推送镜像 tag
  Dev->>Git: 更新 values imageTag
  Argo->>Git: sync
  Argo->>Clu: 滚动 / Rollout Canary
  Cicd->>Argo: 读应用状态
  Cicd->>Web: 构建号 / Sync / 诊断字段
```

分工（ADR-006）：Jenkins 构建制品；Harbor 存镜像；Argo CD 声明式发布；CloudOps 做编排入口与状态聚合，不另起 CD。

---

## 6. 智能运维闭环图（半自动）

```mermaid
stateDiagram-v2
  [*] --> Alert: Alertmanager / 演练
  Alert --> Diagnose: aiops /diagnose<br/>+ 只读 MCP 工具
  Diagnose --> Suggest: remediation/suggest
  Suggest --> PendingApproval: 人工确认
  PendingApproval --> Remediating: Operator 白名单动作
  PendingApproval --> Rejected: 拒绝/过期
  Remediating --> Verified: 指标/日志复核
  Verified --> Retro: /retro/draft
  Retro --> [*]
  Rejected --> [*]
```

硬约束：**AI 与工具默认只读**；高风险变更必须审批；无审批自动 execute、破坏性 full-loop drill 延期（`deferred-week15-22`）。

---

## 7. 安全与命名空间边界（示意）

```mermaid
flowchart TB
  subgraph Identity["身份"]
    RBAC["RBAC: readonly / releaser / approver / admin"]
    SA["专用 ServiceAccount"]
  end

  subgraph Workload["工作负载"]
    PSA["PSA baseline↑"]
    SC["SecurityContext 非特权"]
  end

  subgraph Net["网络"]
    NS["Namespace 隔离"]
    NP["NetPol / Cilium · seclab"]
    TLS["Ingress TLS · cert-manager"]
  end

  subgraph Supply["供应链"]
    Scan["Harbor 扫描规范"]
    Adm["准入 Audit→Enforce 延期"]
  end

  Identity --> Workload --> Net
  Supply --> Workload
```

运行时 Falco 安装、Kyverno Enforce、Harbor 自动扫描开关：见 `deferred-week10-security-followups.md`。

---

## 8. 面试 60 秒讲法（开场）

1. Lab：T430 跑 K8s，harbor-server 跑 Harbor/Rancher/跳板。  
2. 平台：Web → Gateway → observe/cicd/k8s/aiops 微服务。  
3. 交付：Jenkins → Harbor → GitOps/Argo（+ Rollouts）。  
4. 可观测：eBPF/Beyla + Prom + VL + Tempo + Hubble，CloudOps 聚合入口。  
5. AIOps：检索与诊断建议，执行必须审批。  

下一页展开任意一张图即可。

---

## 相关索引

| 主题 | 文档 |
|------|------|
| 环境选型 | 桌面 ADR-001 |
| 日志 / OTel / Istio / 安全 | ADR-002–005 |
| CI/CD / Rollouts | ADR-006–007 |
| FinOps / Chaos / RAG / Operator | ADR-008–011 |
| 延期项 | `docs/deferred-week*-followups.md` |
| KB 语料 | `docs/kb/README.md` |
