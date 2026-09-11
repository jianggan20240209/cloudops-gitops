# cloudops-cicd Jenkins credential（示例，勿提交真实 token）

```bash
# 在 harbor-server 执行；token 用 Jenkins 用户 API Token
kubectl -n cloudops-dev create secret generic cloudops-cicd-jenkins-credential \
  --from-literal=username=admin \
  --from-literal=token='REPLACE_ME' \
  --dry-run=client -o yaml | kubectl apply -f -
```

GitOps：`dev/backend/deployment/go/base/values/cloudops-cicd.yaml` → `jenkins.enabled: true`
