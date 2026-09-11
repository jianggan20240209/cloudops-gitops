# Day 53 · Cilium / Hubble 检查

完整说明：桌面 `专用测试环境/14_Cilium_Hubble检查.md`

## 目标

检查 Cilium、Hubble Peer/Relay/UI；验证 Pod→Pod、Pod→Service、到 Harbor 连通。

## 验收（2026-09-11）

- [x] Cilium agent Ready **10/10**
- [x] hubble-relay / hubble-ui Running；Hubble UI `cloudops-dev` 可见流量（含 → `otel-collector:4318`）
- [x] Pod→Service：`cicd_svc 200` / `gateway_svc 200`（debug curl Pod）
- [x] Pod→Pod IP：`cicd_pod 200`
- [x] Harbor HTTPS：pod + host 均 OK

## 命令

```bash
cd ~/code/cloudops-gitops && git pull
bash scripts/day53-check-cilium-hubble.sh
kubectl -n kube-system port-forward svc/hubble-ui 12000:80
# http://127.0.0.1:12000
```

说明：gateway/cicd 为 scratch 镜像无 wget，连通性用 `library/curl` 诊断 Pod 探测。
