# Day 54 · 网络故障三实验

完整说明：桌面 `专用测试环境/15_网络故障三实验.md`

隔离命名空间：`cloudops-netlab`（不影响 `cloudops-dev`）

## 实验

1. DNS：对 client 下发 deny-all egress → 无法解析 Service  
2. Service：错误 selector → Endpoints 空 → 连通失败  
3. NetworkPolicy：拒绝 client→server → Hubble 可见 dropped/denied  

## 命令

```bash
cd ~/code/cloudops-gitops && git pull
# 会创建 ns / 应用临时 NetworkPolicy，确认后执行：
bash scripts/day54-network-fault-labs.sh all
# 结束后务必：
bash scripts/day54-network-fault-labs.sh cleanup
```

## 验收

- [ ] 三实验均能复现失败并恢复  
- [ ] Hubble UI 选 `cloudops-netlab` 看到 deny/drop（实验 3）  
