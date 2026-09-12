# Day 117 · Backup API 设计

## 目标

CloudOps 提供**只读**备份状态查询，便于 BC 看板与诊断 Agent；写操作（create/restore/delete）走审批，不开放给 MCP 默认工具。

## 建议契约

```http
GET /api/v1/observe/backups?namespace=
GET /api/v1/observe/backups/{name}
```

字段示意：`name`、`phase`、`startTimestamp`、`completionTimestamp`、`errors`、`ttl`、`storageLocation`。

## 数据源

- Velero Backup CR（安装后）  
- etcd 备份元数据可由文件清单/旁路作业暴露（可选）

## 安全

- 只读；不返回对象存储密钥  
- restore/delete：**非**公开 API；对齐 day69

## 相关

- [day114-velero-install-plan.md](day114-velero-install-plan.md)  
- [day118-rto-rpo-bc.md](day118-rto-rpo-bc.md)
