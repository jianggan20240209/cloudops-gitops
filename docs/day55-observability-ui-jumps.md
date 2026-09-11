# Day 55 · CloudOps 观测入口 + eBPF/OTel 一页纸

完整说明：桌面 `专用测试环境/16_CloudOps观测入口与eBPF_OTel权衡一页纸.md`  
对齐：ADR-003

## 交付

1. `cloudops-web` 增加 Grafana / Tempo Explore / Hubble 跳转；日志 `trace_id` → Tempo  
2. 一页纸：自动观测缺口、管道选型、四条权衡、本环境证据链  

## 验收（2026-09-11）

- [x] CloudOps 首页三个跳转可用（`main-11`，Synced/Healthy）  
- [x] 页面可见「Day 55 · 观测入口」/「观测跳转」  
- [ ] Hubble：`0.0.0.0:12000` port-forward 后卡片打开 `https://192.168.1.200:12000`（URL 修正后需再发一版）  
- [x] 一页纸可讲 5–8 分钟  

## 命令

```bash
# Hubble（在 harbor-server 上监听全网卡，供局域网打开）
kubectl -n kube-system port-forward --address 0.0.0.0 svc/hubble-ui 12000:80

# 打开
# https://cloudops.jianggan.cn
# https://grafana.jianggan.cn  → Explore → Tempo
# https://192.168.1.200:12000  → Hubble UI
```

## 发版

Pipeline：`test-cloudops-web-kaniko`（`Jenkinsfile.cloudops-web-kaniko`）  
会构建 `harbor-server.jianggan.cn/cloudops/cloudops-web:main-${BUILD_NUMBER}`，并 **自动 patch** Argo `cloudops-web-dev` 的 `app.imageTag` + sync。

当前运行：`main-11`。Hubble 跳转改为 `https://192.168.1.200:12000` 后需再 Build 一次。
