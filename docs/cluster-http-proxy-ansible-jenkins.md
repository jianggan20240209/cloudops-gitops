# 集群 HTTP/HTTPS 代理：Ansible + Jenkins Helm

外网 tinyproxy（DNAT `8.222.223.161:32001` → 代理机 `8888`）：

| 用途 | 代理 URL |
|------|----------|
| shell / git / curl / Kaniko env | `http://vv-ai:w16y%2A3w2g862@8.222.223.161:32001` |
| systemd dockerd/containerd | `http://vv-ai:w16y*3w2g862@8.222.223.161:32001`（明文 `*`） |
| Jenkins UI 密码框 | 用户 `vv-ai`，密码 `w16y*3w2g862` |

---

## 1. Ansible 批量配置节点系统代理

### 目录

```text
cloudops-gitops/ansible/
  inventory/hosts.example.yml
  group_vars/all/proxy.yml
  playbooks/cluster-http-proxy.yml
  roles/cluster-http-proxy/
```

### 执行

```bash
cd ~/tools/cloudops-gitops/ansible

# 使用 pve-devops-k8s 集群 inventory（master + worker + harbor）
ansible-playbook -i inventory/pve-devops-k8s.yml playbooks/cluster-http-proxy.yml

# 或复制 hosts.example.yml 自定义
cp inventory/hosts.example.yml inventory/hosts.yml
ansible-playbook -i inventory/hosts.yml playbooks/cluster-http-proxy.yml
```

### 每个节点会配置

| 路径 | 作用 |
|------|------|
| `/etc/profile.d/proxy.sh` | 登录 shell 的 `HTTP_PROXY` / `HTTPS_PROXY` |
| `/etc/systemd/system/docker.service.d/http-proxy.conf` | dockerd 代理 |
| `/etc/systemd/system/containerd.service.d/http-proxy.conf` | containerd 代理（`docker pull` 必需） |
| 删除 `proxy.conf` | 避免旧 Clash 配置覆盖 |

### 验证

```bash
source /etc/profile.d/proxy.sh
env | grep -i proxy

systemctl show containerd --property=Environment --no-pager
systemctl show docker --property=Environment --no-pager

curl -I -x "$HTTP_PROXY" --max-time 20 https://github.com
```

---

## 2. Jenkins Helm 部署（带代理）

### values 文件

`dev/platform/jenkins/helm/values-dev.yaml`

### 安装 / 升级

与 harbor-server `~/tools/jenkins/jenkins-values.yaml` 对齐的 values 见：

`dev/platform/jenkins/helm/values-dev.yaml`

```bash
cd ~/tools/jenkins

# 可从 gitops 同步最新 values
cp ~/tools/cloudops-gitops/dev/platform/jenkins/helm/values-dev.yaml jenkins-values.yaml

helm upgrade --install jenkins jenkins/jenkins \
  -n devops \
  --create-namespace \
  -f jenkins-values.yaml \
  --post-renderer ~/tools/cloudops-gitops/scripts/jenkins-helm-post-render.sh
```

### values 中代理相关项

| 配置块 | 作用 |
|--------|------|
| `controller.containerEnv` | Jenkins 控制器 Pod 环境变量 |
| `controller.JCasC.configScripts.proxy` | Jenkins UI HTTP Proxy（SCM 拉 Jenkinsfile） |
| `controller.initScripts.git-proxy` | 控制器内 `git config --global http.proxy` |
| `agent.envVars` | 静态 Agent 默认代理（Kaniko 仍以 Jenkinsfile podTemplate 为准） |

### 部署后验证

```bash
# 控制器 Pod 环境变量
kubectl -n devops exec deploy/jenkins -- env | grep -i proxy

# Jenkins UI: Manage Jenkins → System → HTTP Proxy → Test URL https://github.com

# SCM 拉取
kubectl -n devops exec deploy/jenkins -- \
  git ls-remote https://github.com/jianggan20240209/cloudops-platform.git HEAD
```

或使用脚本：

```bash
export GIT_PROXY='http://vv-ai:w16y%2A3w2g862@8.222.223.161:32001'
JENKINS_NS=devops bash scripts/setup-jenkins-controller-git-proxy-k8s.sh
```

---

## 3. 分工

| 组件 | 代理配置方式 |
|------|----------------|
| 节点 shell / apt / skopeo | Ansible → `/etc/profile.d/proxy.sh` |
| 节点 `docker pull` | Ansible → containerd + docker systemd |
| Jenkins SCM（Jenkinsfile） | Helm JCasC + containerEnv |
| Kaniko Pipeline | `cloudops-platform` Jenkinsfile podTemplate |
| Go 基础镜像 | `harbor-server.jianggan.cn/library/golang:1.23-alpine`（内网 NO_PROXY） |

---

## 4. Init 容器 `Init:Error` 排障

### 插件下载失败（无代理）

`kubectl -n devops logs jenkins-0 -c init` 出现 `Failed to download plugin` / `Connection refused`：

- 确认 `controller.initContainerEnv` 与 `containerEnv` 使用相同 `HTTP_PROXY` / `NO_PROXY`
- 同步 `values-dev.yaml` 后 `helm upgrade` 并 `kubectl delete pod jenkins-0`

### 插件已下载但 `cp: overwrite` 交互失败

日志末尾类似：

```text
Done
copy plugins to shared volume
cp: overwrite '/var/jenkins_plugins/blueocean.jpi'?
```

原因：Helm chart 用 `yes n | cp -i` 复制到 EmptyDir `/var/jenkins_plugins`。init **在同一 Pod 内重试**时目标目录已有 `.jpi`，`yes n` 拒绝覆盖 → Exit 1。

`controller.overwritePlugins: true` **只**删除 PVC 上 `$JENKINS_HOME/plugins/*`，**不会**清空 `/var/jenkins_plugins`；`grep overwrite apply_config.sh` 也可能无匹配（脚本里只有 `rm -rf`，不含字面量 overwrite）。

**立即修复（一次性 patch ConfigMap）：**

```bash
kubectl get cm jenkins -n devops -o yaml \
  | sed 's/yes n | cp -i/cp -f/g' \
  | kubectl apply -f -

kubectl -n devops delete pod jenkins-0
```

**持久修复（helm post-renderer，gitops 已提供）：**

```bash
chmod +x ~/tools/cloudops-gitops/scripts/jenkins-helm-post-render.sh

helm upgrade --install jenkins jenkins/jenkins \
  -n devops \
  -f /root/tools/jenkins/jenkins-values.yaml \
  --post-renderer ~/tools/cloudops-gitops/scripts/jenkins-helm-post-render.sh

kubectl get cm jenkins -n devops -o jsonpath='{.data.apply_config\.sh}' | grep 'cp -f'
kubectl -n devops delete pod jenkins-0
```

### k8s-sidecar ErrImagePull

禁用 JCasC sidecar（集群无法拉 `docker.io/kiwigrid/k8s-sidecar`）：

```yaml
controller:
  sidecars:
    configAutoReload:
      enabled: false
```

---

## 5. 安全

- 生产环境建议 `ansible-vault encrypt group_vars/all/proxy.yml`
- 勿将明文密码提交到公开仓库
