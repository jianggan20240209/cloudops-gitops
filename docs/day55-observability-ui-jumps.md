# Day 55 · CloudOps 观测入口 + eBPF/OTel 一页纸

完整说明：桌面 `专用测试环境/16_CloudOps观测入口与eBPF_OTel权衡一页纸.md`  
对齐：ADR-003

## 交付

1. `cloudops-web` 增加 Grafana / Tempo Explore / Hubble 跳转；日志 `trace_id` → Tempo  
2. 一页纸：自动观测缺口、管道选型、四条权衡、本环境证据链  

## 验收

- [ ] CloudOps 首页三个跳转可用  
- [ ] 真实 `trace_id` 打开 Tempo Explore  
- [ ] Hubble：`port-forward` 后 `127.0.0.1:12000` 可开  
- [ ] 一页纸可讲 5–8 分钟  

## 命令

```bash
# Hubble（本机）
kubectl -n kube-system port-forward svc/hubble-ui 12000:80

# 打开
# https://cloudops.jianggan.cn
# https://grafana.jianggan.cn  → Explore → Tempo
```

## 发版

1. 合并 `cloudops-platform` 中 `services/cloudops-web` 变更  
2. Jenkins 构建 `cloudops-web` Kaniko，记下新 `main-N`  
3.  bump `dev/frontend/deployment/ui/base/values/cloudops-web.yaml` 的 `imageTag` 并 sync Argo  

（直播发版前请确认。）
