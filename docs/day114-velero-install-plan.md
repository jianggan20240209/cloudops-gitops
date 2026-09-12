# Day 114 · Velero 安装计划（Plan only）

状态：**仅计划，禁止未确认 apply / install**

## 目标架构（文档）

```text
Velero (ns: velero)
  → BackupStorageLocation: 对象存储或兼容 S3 端点（凭据走 Secret，不进 git）
  → VolumeSnapshotLocation: 与 CSI / Longhorn 快照能力对齐（按集群实际）
  → Schedule: 业务 ns 白名单；排除 kube-system 等除非明确需要
```

## 前置检查

- [ ] Longhorn（或既有存储类）健康；知悉卷备份限制  
- [ ] 对象存储桶与网络可达（含代理场景单独说明）  
- [ ] RBAC / 命名空间配额足够  
- [ ] 与 etcd 备份职责无混淆（day113）

## 安装步骤（确认后执行）

1. `git pull`  
2. 准备 BSL/凭证 Secret（本地，不提交）  
3. Helm/清单 install Velero  
4. 干跑：`velero backup create dryrun-... --wait`（或等价）  
5. 仅在演练 ns 验证；**delete-restore 见 deferred**

## 明确不做

- 不在本文件触发 live install  
- 不做生产 ns 全量定期备份直到 RTO/RPO 评审通过（day118）

## 相关

- [day117-backup-api.md](day117-backup-api.md)  
- [deferred-week15-22-runtime-followups.md](deferred-week15-22-runtime-followups.md)
