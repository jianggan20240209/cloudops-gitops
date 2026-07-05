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

### 代理地址与密码转义

外网 tinyproxy（DNAT `8.222.223.161:32001` → 代理机 `8888`）：

| 项 | 值 |
|---|---|
| 明文密码 | `w16y*3w2g862` |
| URL 中 `*` | 写成 **`%2A`** |
| 完整代理 URL | `http://vv-ai:w16y%2A3w2g862@8.222.223.161:32001` |

**不同场景写法：**

| 场景 | 密码写法 |
|------|----------|
| git / curl / shell `HTTP_PROXY` | `%2A`（URL 编码） |
| Jenkins UI「HTTP Proxy」密码框 | 明文 `*` |
| systemd `docker.service.d` | 明文 `*`（`%2A` 会导致 HTTP_PROXY 加载失败） |

### 方式 A：Jenkins UI（推荐）

Helm/JCasC 部署时，HTTP Proxy 写在 **`jenkins.proxy`**（见 `values-dev.yaml` 的 `configScripts.proxy`）。勿使用已废弃的 `unclassified.proxyConfiguration`，也不要把字段放在 `unclassified.proxyConfigurationManager` 下；详见 `docs/cluster-http-proxy-ansible-jenkins.md`。

1. **Manage Jenkins → System → HTTP Proxy Configuration**
2. 填写：
   - Server: `8.222.223.161`
   - Port: `32001`
   - Username: `vv-ai`
   - Password: `w16y*3w2g862`（UI 填明文，不要填 `%2A`）
3. **No Proxy Host** 建议包含：

```text
localhost,127.0.0.1,::1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12,.svc,.cluster.local,.jianggan.cn,harbor-server.jianggan.cn,jenkins.jianggan.cn,argocd.jianggan.cn,docker.m.daocloud.io,daocloud.io
```

4. 保存后重试 `test-cloudops-cicd-kaniko`

### 方式 B：Jenkins 用户 gitconfig

在 **Jenkins 控制器**执行（不是 harbor-server）：

```bash
# 若 Jenkins 跑在容器内，先进入控制器 Pod
# kubectl -n devops exec -it deploy/jenkins -- bash

git config --global http.proxy  'http://vv-ai:w16y%2A3w2g862@8.222.223.161:32001'
git config --global https.proxy 'http://vv-ai:w16y%2A3w2g862@8.222.223.161:32001'
git config --global http.version HTTP/1.1
git config --global http.lowSpeedLimit 0
git config --global http.lowSpeedTime 999999

git config --global --list | grep -E 'proxy|http.version'
git ls-remote https://github.com/jianggan20240209/cloudops-platform.git HEAD
```

Jenkins Home 通常在 `/var/jenkins_home`，gitconfig 写入 `/var/jenkins_home/.gitconfig`。

仓库内提供辅助脚本（可传入 `GIT_PROXY`）：

```bash
export GIT_PROXY='http://vv-ai:w16y%2A3w2g862@8.222.223.161:32001'
bash scripts/setup-jenkins-controller-git-proxy-k8s.sh
```

不要在本机 harbor-server 直接执行 `JENKINS_HOME=/var/jenkins_home bash scripts/setup-jenkins-controller-git-proxy.sh`，除非当前 shell 就在 Jenkins 控制器内。

## 2. 验证代理可达

在 Jenkins 控制器或 harbor-server 上：

```bash
# curl 使用 URL 编码密码 %2A
curl -I -x 'http://vv-ai:w16y%2A3w2g862@8.222.223.161:32001' --max-time 20 https://github.com

# git 一次性指定代理（同样用 %2A）
git -c http.proxy='http://vv-ai:w16y%2A3w2g862@8.222.223.161:32001' \
    -c https.proxy='http://vv-ai:w16y%2A3w2g862@8.222.223.161:32001' \
    ls-remote https://github.com/jianggan20240209/cloudops-platform.git HEAD
```

若这里失败，先修复到 `8.222.223.161:32001` 的网络/认证，而不是改 Jenkinsfile。

## 3. Agent Pod 内 Checkout（Pipeline 阶段）

`cloudops-platform` 三个 Kaniko Jenkinsfile 在 `environment` 中设置 Git 2.35+ 的 **`GIT_CONFIG_*`** 变量，对 Git 插件调用的 `git fetch` 生效：

```text
GIT_CONFIG_KEY_0 / GIT_CONFIG_VALUE_0 = http.version / HTTP/1.1
GIT_CONFIG_KEY_1 / GIT_CONFIG_VALUE_1 = http.proxy  / http://vv-ai:w16y%2A3w2g862@8.222.223.161:32001
GIT_CONFIG_KEY_2 / GIT_CONFIG_VALUE_2 = https.proxy / (同上)
```

勿使用 `GitConfigOption`（当前集群 Git 插件无此 extension）。`Prepare Git` 日志里 `http.proxy=` 可能被 Jenkins **脱敏**为空，不代表未设置。

在 Agent Pod 内验证（替换 Pod 名）：

```bash
kubectl -n devops exec -it <agent-pod> -c jnlp -- sh -c \
  "export GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_0=http.version GIT_CONFIG_VALUE_0=HTTP/1.1 \
   GIT_CONFIG_KEY_1=http.proxy GIT_CONFIG_VALUE_1='http://vv-ai:w16y%2A3w2g862@8.222.223.161:32001' && \
   git ls-remote https://github.com/jianggan20240209/cloudops-platform.git HEAD"
```

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
