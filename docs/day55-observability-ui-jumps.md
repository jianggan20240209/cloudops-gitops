# Day 55 · CloudOps 观测入口 + eBPF/OTel 一页纸

完整说明：桌面 `专用测试环境/16_CloudOps观测入口与eBPF_OTel权衡一页纸.md`  
对齐：ADR-003

## 交付

1. `cloudops-web` 增加 Grafana / Tempo Explore / Hubble 跳转；日志 `trace_id` → Tempo  
2. 一页纸：自动观测缺口、管道选型、四条权衡、本环境证据链  

## 验收（2026-09-11）

- [x] CloudOps 首页三个跳转可用（含 Hubble `https://192.168.1.200:12000`）  
- [x] 页面可见「Day 55 · 观测入口」/「观测跳转」  
- [x] Hubble 跳转 URL 已上线（`main-11` 之后含 `192.168.1.200:12000` 的发版）  
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

当前运行：含 Hubble `http://192.168.1.200:12000` 的发版（port-forward 为 HTTP；HTTPS 会 `ERR_SSL_PROTOCOL_ERROR`）。

## Tempo Explore `fields` 崩溃（非 DNS）

现象：Grafana Explore → Tempo 报 `TypeError: Cannot read properties of undefined (reading 'fields')`。

**不是** CoreDNS 缺 `grafana.jianggan.cn`：页面已能打开即说明浏览器侧解析正常（本环境一般是 `192.168.1.210`）。

常见原因与处理：

1. 跳转 URL 使用了新式 `panes=` Explore 状态 → 部分 Grafana 前端会崩；改用经典 `left=`（`cloudops-web` `f68f0b0`）。
2. Tempo datasource 里 `tracesToLogs` / `lokiSearch` 的 `datasourceUid: ""` → 去掉空 uid（gitops `6634373`）。

手工验收：Grafana → Explore → 选 Tempo → TraceQL Search，不要带坏的 `panes=` 书签 URL。
