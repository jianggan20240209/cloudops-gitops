# Day 71 · Jenkins + Harbor 模块设计

完整：桌面 `专用测试环境/32_第11周_Jenkins_Harbor构建制品治理.md`

## 边界

| 层 | 职责 |
|---|---|
| `jenkins_build.ps1` / `.py` | 生产双 Jenkins CLI 参考（匹配/触发/队列/webhook） |
| `cloudops-cicd` | Lab 平台 API：单 Jenkins（`jenkins.jianggan.cn`）+ Harbor tag 约定 |
| Harbor | 制品仓；tag 规范 `main-<BUILD_NUMBER>` |
| Argo CD | 消费镜像 tag（不在本周重做） |

## Job 匹配（Lab）

优先：`test-<svc>-kaniko` → `<svc>-kaniko` → 唯一 substring；歧义时优先 `*-kaniko`。

## Tag

触发前：`main-pending`（或 `<branch>-pending`）  
构建号已知后：`<branch>-<BUILD_NUMBER>`（与现有 Kaniko 流水线一致）。

## 密钥

集群 Secret：`cloudops-cicd-jenkins-credential`（`username` / `token`），不入库。
