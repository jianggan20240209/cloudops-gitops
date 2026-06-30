# Jenkins 从 GitHub 拉取 Jenkinsfile 失败排障

## 现象

```text
fatal: unable to access 'https://github.com/jianggan20240209/cloudops-platform.git/':
GnuTLS, handshake failed: The TLS connection was non-properly terminated.
```

发生在 **Loading pipeline from SCM**，尚未进入 `Jenkinsfile.*` 的任何 stage。

因此：

- 修改 `Jenkinsfile` 内 `Prepare Git` **不能**解决此错误
- 必须在 **Jenkins 控制器**（拉取 SCM 的那台机器/容器）配置 Git 代理

## 1. 在 Jenkins 控制器配置 Git 代理

### 方式 A：Jenkins UI（推荐）

1. **Manage Jenkins → System → HTTP Proxy Configuration**
2. 填写：
   - Server: `192.168.1.50`
   - Port: `7890`
3. **No Proxy Host** 建议包含：

```text
localhost,127.0.0.1,::1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12,.svc,.cluster.local,.jianggan.cn,harbor-server.jianggan.cn,jenkins.jianggan.cn,argocd.jianggan.cn
```

4. 保存后重试 `test-cloudops-cicd-kaniko`

### 方式 B：Jenkins 用户 gitconfig

在 **Jenkins 控制器**执行（不是 harbor-server）：

```bash
# 若 Jenkins 跑在容器内，先进入控制器 Pod
# kubectl -n <jenkins-namespace> exec -it deploy/jenkins -- bash

export GIT_PROXY=http://192.168.1.50:7890
git config --global http.proxy "${GIT_PROXY}"
git config --global https.proxy "${GIT_PROXY}"
git config --global http.version HTTP/1.1
git config --global http.lowSpeedLimit 0
git config --global http.lowSpeedTime 999999

git config --global --list | grep -E 'proxy|http.version'
git ls-remote https://github.com/jianggan20240209/cloudops-platform.git HEAD
```

Jenkins Home 通常在 `/var/jenkins_home`，gitconfig 写入 `/var/jenkins_home/.gitconfig`。

仓库内提供辅助脚本：

```bash
# 在 harbor-server 上通过 kubectl 进入 Jenkins 控制器 Pod 配置
bash scripts/setup-jenkins-controller-git-proxy-k8s.sh

# 若已知 Jenkins Pod
JENKINS_NS=jenkins JENKINS_POD=jenkins-0 bash scripts/setup-jenkins-controller-git-proxy-k8s.sh
```

不要在本机 harbor-server 直接执行 `JENKINS_HOME=/var/jenkins_home bash scripts/setup-jenkins-controller-git-proxy.sh`，除非当前 shell 就在 Jenkins 控制器内。

## 2. 验证代理可达

在 Jenkins 控制器上：

```bash
curl -x http://192.168.1.50:7890 -I https://github.com
curl -x http://192.168.1.50:7890 -I https://github.com/jianggan20240209/cloudops-platform.git
```

若这里失败，先修复 Jenkins → `192.168.1.50:7890` 网络，而不是改 Jenkinsfile。

## 3. Jenkinsfile 内代理（Pipeline 阶段）

`cloudops-platform` 三个 Kaniko Jenkinsfile 已配置：

```text
HTTP_PROXY / HTTPS_PROXY / http_proxy / https_proxy = http://192.168.1.50:7890
Prepare Git:
  git config --global http.proxy http://192.168.1.50:7890
  git config --global https.proxy http://192.168.1.50:7890
```

这只在 Pipeline **进入 stage 后**生效，用于 Checkout 源码和 Kaniko `go mod download`。

## 4. 临时绕过（不依赖 Jenkins）

若 Jenkins SCM 仍失败，可在 harbor-server 手动构建部署 `cloudops-cicd`：

```bash
cd ~/tools/cloudops-gitops && git pull
bash scripts/build-cloudops-cicd-manual.sh
bash scripts/verify-cloudops-gateway-release-snapshot.sh
bash scripts/verify-cloudops-gateway-release-snapshot.sh
```

## 5. 其他可选方案

若 HTTPS + GnuTLS 持续失败：

1. Jenkins 任务 SCM URL 改为 SSH：`git@github.com:jianggan20240209/cloudops-platform.git` + Deploy Key
2. 在内网 Harbor/Gitea 镜像 `cloudops-platform`，Jenkins SCM 指向内网地址
3. 升级 Jenkins 控制器上的 `git` 客户端版本

## 6. 成功标准

Jenkins 构建日志应出现：

```text
[Pipeline] Start of Pipeline
...
[Pipeline] stage (Prepare Git)
[Pipeline] stage (Checkout)
```

而不是在 `Started by user` 后直接 `GitException` 退出。
