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

Pipeline：`test-cloudops-web-kaniko`（`Jenkinsfile.cloudops-web-kaniko`）  
会构建 `harbor-server.jianggan.cn/cloudops/cloudops-web:main-${BUILD_NUMBER}`，并 **自动 patch** Argo `cloudops-web-dev` 的 `app.imageTag` + sync。

```bash
# 在能访问 Jenkins 的机器上触发（或 UI Build Now）
# Job: test-cloudops-web-kaniko
# 代码已在 cloudops-platform main：ce13ae7

# 验收
curl -sk https://cloudops.jianggan.cn/ | grep -E 'Day 55|观测跳转'
kubectl -n cloudops-dev get deploy cloudops-web -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```
