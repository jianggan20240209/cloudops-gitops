# Day 54 · 网络故障三实验

完整说明：桌面 `专用测试环境/15_网络故障三实验.md`

隔离命名空间：`cloudops-netlab`（不影响 `cloudops-dev`）

## 实验

1. DNS：对 client 下发 deny-all egress → 无法解析 Service  
2. Service：错误 selector → Endpoints 空 → 连通失败  
3. NetworkPolicy：拒绝 client→server → Hubble 可见 dropped/denied  

## 验收（2026-09-11）

- [x] 基线 `day54-server` svc → **HTTP 200**（EndpointSlice 有地址）
- [x] EXP1：before 200 → deny 后 000 → restore 200
- [x] EXP2：good svc 200 / broken svc 000（broken EndpointSlice 无地址）
- [x] EXP3：before 200 → deny 后 000 → cleanup 后 200
- [ ] Hubble UI 选 `cloudops-netlab` 看 deny/drop（实验 3，可选复核）

## 命令

```bash
cd ~/code/cloudops-gitops && git pull
bash scripts/day54-network-fault-labs.sh all
# 结束后务必：
bash scripts/day54-network-fault-labs.sh cleanup
```

说明：`8cc4bd0` 起脚本会等 EndpointSlice、修 curl `000` 双拼；基线非 200 时 `diag` 退出。
