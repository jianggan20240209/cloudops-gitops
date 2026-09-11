# Day 66 · 网络 / Secret / TLS / 网格安全规范

完整：桌面 `专用测试环境/27_网络Secret与网格安全规范.md`

## Namespace 隔离

- 业务：`cloudops-dev`；观测：`monitoring`/`logging`/`tracing`；演练：`cloudops-netlab`/`cloudops-faultlab`/`cloudops-seclab`
- 禁止跨 ns 随意挂 SA token

## NetworkPolicy / Cilium

- 示例（**仅 seclab**）：`dev/platform/security/network/seclab-default-deny.yaml`
- 生产业务 default-deny 需白名单 DNS/监控后再开；本周用 seclab 验证 + Hubble

## Ingress TLS

- 统一 `cert-manager` + `jianggan-ca-issuer`；主机 `*.jianggan.cn`

## Secret

- 禁止明文进 Git；Harbor/Argo/邮件凭据用 K8s Secret
- 轮换记录进复盘

## Istio（后续验证范围，对齐 ADR-004）

- [ ] PeerAuthentication STRICT（选中工作负载）
- [ ] AuthorizationPolicy：默认 deny + 显式 allow
- [ ] 不把基础设施强制进 mesh
