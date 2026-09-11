# Day 53 · Cilium / Hubble 检查

完整说明：桌面 `专用测试环境/14_Cilium_Hubble检查.md`

## 目标

检查 Cilium、Hubble Peer/Relay/UI；验证 Pod→Pod、Pod→Service、到 Harbor 连通。

## 验收

- [ ] Cilium agent Ready
- [ ] hubble-relay / hubble-ui Ready
- [ ] cloudops-dev 内 Pod→Service / Pod→Pod 成功
- [ ] 可访问 Harbor HTTPS
- [ ] Hubble UI 或 `hubble observe` 能看到流量

## 命令

```bash
cd ~/code/cloudops-gitops && git pull
bash scripts/day53-check-cilium-hubble.sh

# Hubble UI（可选）
kubectl -n kube-system port-forward svc/hubble-ui 12000:80
# 浏览器 http://127.0.0.1:12000
```
