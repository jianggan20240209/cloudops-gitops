# Day 113 · etcd 备份 SOP

桌面复盘：`专用测试环境/38_第17周复盘_备份与业务连续性.md`

## 范围

- **保**：集群控制面真相（API 对象）  
- **不保**：应用 PVC 数据内容（交给 Longhorn / Velero 卷备份叙事，见 day114/118）

## 原则

1. 定期快照 + 异机保留（路径与保留天数在现场 runbook 填写，**本文不写密钥**）。  
2. 备份校验：定期 `etcdctl snapshot status`（或等价检查）。  
3. **restore 到 live 必须单独审批窗口**（deferred）。

## 操作提纲（控制面节点执行；细节随发行版调整）

```bash
# 1) 确认 etcd 成员与端点健康（示例）
sudo etcdctl endpoint health

# 2) 打快照（输出路径按现场约定）
sudo etcdctl snapshot save /var/lib/etcd-backup/etcd-$(date +%F-%H%M).db

# 3) 校验
sudo etcdctl snapshot status /var/lib/etcd-backup/etcd-YYYY-MM-DD-HHMM.db -w table

# 4) 复制到异机（scp/rsync；勿把凭证写入 git）
```

> 实际证书路径、容器化 etcd 的 `etcdctl` 包装以集群安装文档为准；执行前 `git pull` 相关 runbook。

## 验收（文档级）

- [ ] 存在可还原的最近 N 份快照  
- [ ] 异机可列出文件  
- [ ] 状态检查通过  
- [ ] restore 演练仅在延期项批准后进行

## 相关

- [day114-velero-install-plan.md](day114-velero-install-plan.md)  
- [day118-rto-rpo-bc.md](day118-rto-rpo-bc.md)
