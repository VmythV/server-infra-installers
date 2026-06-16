# 基础软件一键安装仓库方案

## 1. 目标

当前目录定位为“基础软件一键安装项目仓库”，用于用项目管理方式维护多种基础软件的安装脚本、manifest、工具和发布包。

第一阶段先实现 Kubernetes 单节点快速部署。后续可以在同一仓库中继续增加 Docker、containerd、Helm、监控组件、日志组件等安装脚本。

重要边界：

- 不是使用一个脚本安装所有软件。
- 一个软件对应一个独立安装脚本。
- 不同软件可以有不同访问地址，例如 Kubernetes 使用 `https://k8s-install.example.cn/install.sh`，Docker 后续可以使用 `https://docker-install.example.cn/install.sh`。
- 当前目录只负责用项目结构管理这些不同软件的脚本、配置、工具和发布物。

Kubernetes 默认交互式安装：

```bash
curl -fsSL https://k8s-install.example.cn/install.sh | sh
```

中国大陆网络环境使用：

```bash
curl -fsSL https://k8s-install.example.cn/install.sh | CN=1 sh
```

如果用户希望无人值守安装，可以通过环境变量一次性传入所有配置：

```bash
curl -fsSL https://k8s-install.example.cn/install.sh | \
  ASSUME_YES=1 CN=1 K8S_DATA_ROOT=/data/kubernetes sh
```

仓库目标：

- 作为基础软件安装脚本的项目仓库。
- 每个基础软件独立成目录，例如 `k8s/`、`docker/`。
- 每个软件目录都有自己的 `install.sh`、`config.env`、`scripts/`、`tools/`、发布配置。
- 每个软件独立发布、独立访问、独立安装。
- 可以维护公共模板和规范，但不设计一个总安装入口。

Kubernetes 第一版目标：

- Kubernetes 固定版本：`v1.35.5`
- 容器运行时：`containerd`
- 部署方式：`kubeadm`
- CNI：`Calico`
- 指标组件：`metrics-server`
- 入口组件：`Traefik`
- 支持单节点调度业务 Pod
- 支持 kubeadm 证书自动续期
- 支持已安装检测，重复执行不破坏已有集群
- 默认使用官方源、官方下载地址和官方镜像，适合海外或可直接访问官方资源的环境
- 设置 `CN=1` 时启用中国大陆可访问的软件源、下载地址和镜像改写
- 容器镜像加速前缀通过环境变量配置，默认中国模式使用华为云 DDN 镜像前缀
- Kubernetes 相关数据目录可自定义，包括 containerd 镜像、kubelet 数据、资源文件、PV/PVC、本地存储等
- 必须记录每一步操作，失败时必须记录失败步骤、命令、退出码和日志位置

不建议最终使用 `https://chatgpt.com/codex/install.sh` 作为脚本分发地址。`chatgpt.com` 不是稳定的软件分发域名，中国大陆访问也不可控。建议使用一个全球可访问域名，并为中国大陆配置 CDN 或镜像域名。`CN=1` 时脚本使用中国大陆可访问的安装包、软件源和镜像。

## 2. Traefik 与 Envoy Gateway 选择

### 2.1 推荐结论

第一版默认安装 `Traefik`，保留 `Envoy Gateway` 为后续可选项。

原因：

- 使用者接受成本更低。大多数 Kubernetes 使用者已经熟悉 `Ingress`，只需要设置 `ingressClassName: traefik`。
- 从 nginx ingress controller 迁移到 Traefik 的概念成本较低，仍然可以沿用传统 `Ingress` 资源。
- Traefik 同时支持 Kubernetes Ingress、Traefik CRD 和 Gateway API，后续扩展空间足够。
- 单节点快速部署场景中，Traefik 的默认体验更直接，排障路径更短。
- 第一版目标是让新机器快速可用，优先降低使用门槛，而不是强制用户立即切换到 Gateway API。

### 2.2 Envoy Gateway 的定位

Envoy Gateway 仍然是值得保留的后续选项：

- 它基于 Envoy Proxy 实现 Kubernetes Gateway API，更贴近 Kubernetes 网络入口的长期演进方向。
- Gateway API 比传统 Ingress 表达能力更强，适合平台化、标准化和复杂流量治理。
- 如果后续要做灰度、限流、重试、超时、熔断、JWT、OIDC、mTLS 等能力，Envoy Gateway 的扩展路径更清晰。

但它对普通使用者的接受成本更高，需要理解 `GatewayClass`、`Gateway`、`HTTPRoute` 等新资源模型。因此第一版不默认安装 Envoy Gateway。

### 2.3 为什么不使用 nginx ingress controller

不默认安装 `kubernetes/ingress-nginx`。

原因：

- `kubernetes/ingress-nginx` 已进入退休状态。
- 官方文档说明 best-effort 维护到 `2026-03`，之后不再发布、不再修 bug、不再修安全漏洞。
- GitHub 仓库已在 `2026-03-24` 归档。

因此第一版不应再把它作为默认入口组件。

### 2.4 第一版入口能力

第一版安装 Traefik，并启用：

- Kubernetes Ingress Provider
- 默认 `IngressClass: traefik`
- NodePort 暴露方式

默认端口：

```bash
TRAEFIK_HTTP_NODEPORT="30080"
TRAEFIK_HTTPS_NODEPORT="30443"
```

业务默认使用传统 `Ingress`：

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example
spec:
  ingressClassName: traefik
  rules:
    - host: example.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: example-service
                port:
                  number: 80
```

后续版本可以增加：

```bash
INGRESS_CONTROLLER="envoy-gateway"
```

用于安装 Envoy Gateway 和 Gateway API 相关资源。

## 3. CIDR 方案

`POD_CIDR` 和 `SERVICE_CIDR` 是两段不同的集群内网：

- `POD_CIDR`：Pod IP 地址池，由 CNI 使用。
- `SERVICE_CIDR`：ClusterIP Service 地址池，由 kube-apiserver 使用。

默认配置：

```bash
POD_CIDR="10.244.0.0/16"
SERVICE_CIDR="10.96.0.0/12"
```

说明：

- `10.244.0.0/16` 常见于 Flannel，但 Calico 也可以使用，并不是 Flannel 专属。
- `10.96.0.0/12` 是 kubeadm 常见默认 Service 网段。
- 不默认使用 `192.168.0.0/16`，因为它和办公网、家用网、机房内网冲突概率高。
- `10.233.0.0/16` 也可以使用，它常见于 Kubespray，但不是 Kubernetes 或 Calico 的强制要求。

安装前必须做网段冲突检测：

- 检查宿主机所有网卡 IP。
- 检查默认路由。
- 检查现有路由表。
- 检查 Docker、Podman、containerd 可能已有的 bridge 网段。
- 如发现与 `POD_CIDR` 或 `SERVICE_CIDR` 冲突，交互模式下提示用户修改；无人值守模式下直接失败。

允许用户覆盖：

```bash
curl -fsSL https://k8s-install.example.cn/install.sh | \
  POD_CIDR=10.233.0.0/16 SERVICE_CIDR=10.96.0.0/12 sh
```

## 4. 网络访问策略

第一版采用双模式：

- 默认模式：面向海外或可直接访问官方资源的环境，使用官方源、官方 URL 和官方镜像。
- 中国模式：设置 `CN=1` 后启用，所有安装阶段网络访问都必须中国大陆可访问。

默认模式示例：

```bash
curl -fsSL https://k8s-install.example.cn/install.sh | sh
```

中国模式示例：

```bash
curl -fsSL https://k8s-install.example.cn/install.sh | CN=1 sh
```

### 4.1 默认模式

默认模式允许访问官方资源，例如：

```text
github.com
raw.githubusercontent.com
registry.k8s.io
docker.io
quay.io
ghcr.io
```

默认模式不改写镜像，除非用户显式启用：

```bash
REWRITE_IMAGES=true
IMAGE_MIRROR_PREFIX="..."
```

### 4.2 中国模式

`CN=1` 时，安装阶段禁止直接访问以下地址：

```text
github.com
raw.githubusercontent.com
registry.k8s.io
k8s.gcr.io
gcr.io
docker.io
quay.io
ghcr.io
```

`CN=1` 时，安装阶段只允许访问中国大陆可用地址，例如：

```text
k8s-install.example.cn
repo.huaweicloud.com
mirrors.aliyun.com
mirrors.tencent.com
swr.cn-north-4.myhuaweicloud.com
```

原则：

- 默认模式可以使用官方源和官方镜像。
- `CN=1` 时，最终用户执行 `install.sh` 不从 GitHub 下载任何 YAML。
- Calico、metrics-server、Traefik 等 manifest 必须在维护阶段提前下载。
- 下载后必须审计其中所有镜像。
- `CN=1` 时，所有非国内镜像必须改写成 `IMAGE_MIRROR_PREFIX` 前缀。
- `CN=1` 时，改写后的 manifest 随安装包发布到中国大陆可访问地址。

## 5. 镜像改写规则

镜像改写只在以下场景启用：

- `CN=1`
- 或用户显式设置 `REWRITE_IMAGES=true`

默认镜像前缀：

```bash
IMAGE_MIRROR_PREFIX="swr.cn-north-4.myhuaweicloud.com/ddn-k8s"
```

用户可以覆盖：

```bash
curl -fsSL https://k8s-install.example.cn/install.sh | \
  CN=1 IMAGE_MIRROR_PREFIX=registry.example.cn/k8s-mirror sh
```

非中国模式也可以显式启用镜像改写：

```bash
curl -fsSL https://k8s-install.example.cn/install.sh | \
  REWRITE_IMAGES=true IMAGE_MIRROR_PREFIX=registry.example.com/k8s-mirror sh
```

改写规则：

```text
<原始镜像>
```

改为：

```text
swr.cn-north-4.myhuaweicloud.com/ddn-k8s/<原始镜像>
```

示例：

```text
registry.k8s.io/kube-apiserver:v1.35.5
```

改为：

```text
swr.cn-north-4.myhuaweicloud.com/ddn-k8s/registry.k8s.io/kube-apiserver:v1.35.5
```

```text
docker.io/calico/node:vX.Y.Z
```

改为：

```text
swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/calico/node:vX.Y.Z
```

```text
docker.io/traefik:vX.Y.Z
```

改为：

```text
swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/traefik:vX.Y.Z
```

```text
docker.io/library/busybox:1.36
```

改为：

```text
swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/library/busybox:1.36
```

## 6. 默认配置

```bash
K8S_VERSION="1.35.5"

ASSUME_YES="${ASSUME_YES:-0}"
NON_INTERACTIVE="${NON_INTERACTIVE:-0}"
CN="${CN:-0}"

IMAGE_MIRROR_PREFIX="${IMAGE_MIRROR_PREFIX:-swr.cn-north-4.myhuaweicloud.com/ddn-k8s}"
REWRITE_IMAGES="${REWRITE_IMAGES:-false}"

if [ "$CN" = "1" ]; then
  K8S_IMAGE_REPO="${IMAGE_MIRROR_PREFIX}/registry.k8s.io"
  REWRITE_IMAGES="true"
else
  if [ "$REWRITE_IMAGES" = "true" ]; then
    K8S_IMAGE_REPO="${IMAGE_MIRROR_PREFIX}/registry.k8s.io"
  else
    K8S_IMAGE_REPO="registry.k8s.io"
  fi
fi

POD_CIDR="10.244.0.0/16"
SERVICE_CIDR="10.96.0.0/12"

CNI="calico"

INSTALL_METRICS_SERVER="true"
INSTALL_INGRESS="true"
INGRESS_CONTROLLER="traefik"
TRAEFIK_HTTP_NODEPORT="30080"
TRAEFIK_HTTPS_NODEPORT="30443"

ALLOW_SINGLE_NODE_SCHEDULING="true"

CERT_RENEW_ENABLE="true"
CERT_RENEW_THRESHOLD_DAYS="90"

K8S_DATA_ROOT="${K8S_DATA_ROOT:-/var/lib/k8s-installer-data}"
CONTAINERD_ROOT_DIR="${CONTAINERD_ROOT_DIR:-${K8S_DATA_ROOT}/containerd/root}"
CONTAINERD_STATE_DIR="${CONTAINERD_STATE_DIR:-${K8S_DATA_ROOT}/containerd/state}"
KUBELET_ROOT_DIR="${KUBELET_ROOT_DIR:-${K8S_DATA_ROOT}/kubelet}"
KUBELET_POD_LOG_DIR="${KUBELET_POD_LOG_DIR:-${K8S_DATA_ROOT}/logs/pods}"
ETCD_DATA_DIR="${ETCD_DATA_DIR:-${K8S_DATA_ROOT}/etcd}"
K8S_MANIFEST_DIR="${K8S_MANIFEST_DIR:-${K8S_DATA_ROOT}/manifests}"
K8S_RESOURCE_DIR="${K8S_RESOURCE_DIR:-${K8S_DATA_ROOT}/resources}"
K8S_LOCAL_PV_ROOT="${K8S_LOCAL_PV_ROOT:-${K8S_DATA_ROOT}/local-pv}"
K8S_PVC_ROOT="${K8S_PVC_ROOT:-${K8S_DATA_ROOT}/pvc}"
K8S_DOWNLOAD_DIR="${K8S_DOWNLOAD_DIR:-${K8S_DATA_ROOT}/downloads}"
K8S_BACKUP_DIR="${K8S_BACKUP_DIR:-${K8S_DATA_ROOT}/backups}"
```

目录覆盖示例：

```bash
curl -fsSL https://k8s-install.example.cn/install.sh | K8S_DATA_ROOT=/data/kubernetes CN=1 sh
```

## 7. 安装流程

### 7.1 环境检测

检测内容：

- 当前用户是否为 root，或是否可 sudo。
- 操作系统发行版和版本。
- CPU 架构：`amd64`、`arm64`。
- 是否已有 Kubernetes 集群。
- 是否已有 containerd。
- 是否已有 kubeadm、kubelet、kubectl。
- swap 是否开启。
- SELinux 状态。
- firewalld 或 ufw 状态。
- 路由表是否与 `POD_CIDR`、`SERVICE_CIDR` 冲突。
- 默认模式检查官方源是否可访问。
- `CN=1` 时检查中国大陆镜像源、安装包地址和镜像仓库是否可访问。

### 7.2 幂等判断

重复执行时不破坏已有集群：

- 如果 `kubectl get nodes` 正常，输出集群状态并退出。
- 如果 `/etc/kubernetes/admin.conf` 存在，不重复执行 `kubeadm init`。
- 如果 containerd 已安装，只检查和修正 Kubernetes 必需配置。
- 如果 kubeadm、kubelet、kubectl 已安装，检查版本是否为 `1.35.5`。
- 如果 Calico 已安装，不重复安装。
- 如果 metrics-server 已安装，不重复安装。
- 如果 Traefik 已安装，不重复安装。
- 如果证书续期 timer 已存在，不重复创建。

### 7.3 系统初始化

执行内容：

- 关闭 swap，并持久化。
- 加载内核模块：
  - `overlay`
  - `br_netfilter`
- 配置 sysctl：

```text
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
```

- RHEL 系将 SELinux 设置为 permissive 或 disabled，具体策略由配置项控制。
- 不默认关闭防火墙。脚本应输出需要开放的端口。

### 7.4 初始化数据目录

所有 Kubernetes 相关数据可以通过 `K8S_DATA_ROOT` 统一指定根目录。脚本必须在该根目录下创建不同子目录，分别存储不同类型的数据，避免混放。

默认：

```text
/var/lib/k8s-installer-data
```

示例：

```bash
curl -fsSL https://k8s-install.example.cn/install.sh | K8S_DATA_ROOT=/data/kubernetes sh
```

目录布局：

```text
${K8S_DATA_ROOT}/
  containerd/
    root/                 # containerd 镜像、快照、内容存储
    state/                # containerd 运行时状态
  kubelet/                # kubelet root-dir，Pod、volume、plugin 数据
  etcd/                   # 单节点 etcd 数据
  manifests/              # 安装器使用的固定 manifest
  resources/              # kubeadm config、渲染后的资源文件、smoke test yaml
  local-pv/               # 本地 PV 默认根目录
  pvc/                    # 预留给本地 PVC/动态供应器的数据根目录
  downloads/              # 安装包、校验文件、临时下载内容
  backups/                # 证书、配置和关键文件备份
  logs/
    pods/                 # Pod/容器日志目录
    installer/            # 可选安装日志副本，主日志仍写 /var/log
```

要求：

- 脚本启动早期创建这些目录。
- 目录必须归属 root。
- 权限默认 `0755`，敏感目录如 backups 可使用 `0700`。
- 如果目录所在文件系统空间不足，安装前失败。
- 如果目录路径已经存在，不能清空，只能复用或创建缺失子目录。
- 不允许自动删除用户目录中的已有文件。

### 7.5 安装 containerd

要求：

- 默认模式使用官方或发行版默认软件源。
- `CN=1` 时使用中国大陆可访问软件源。
- 配置 `SystemdCgroup = true`。
- 默认模式 pause 镜像使用官方镜像。
- `CN=1` 时 pause 镜像使用 `IMAGE_MIRROR_PREFIX` 改写后的镜像。
- containerd 镜像、内容、快照存储目录使用 `CONTAINERD_ROOT_DIR`。
- containerd 运行状态目录使用 `CONTAINERD_STATE_DIR`。
- 启动并设置开机自启。

containerd 配置示例：

```toml
root = "${CONTAINERD_ROOT_DIR}"
state = "${CONTAINERD_STATE_DIR}"
```

### 7.6 安装 Kubernetes 组件

安装：

- `kubeadm=1.35.5`
- `kubelet=1.35.5`
- `kubectl=1.35.5`

要求：

- 默认模式使用官方 Kubernetes 软件源。
- `CN=1` 时使用中国大陆可访问 Kubernetes 软件源。
- 如果源中不存在 `1.35.5`，安装失败，不自动降级或升级。
- 安装后锁定版本，避免系统升级误升级 kubelet。
- kubelet 数据目录使用 `KUBELET_ROOT_DIR`。
- Pod/容器日志目录使用 `KUBELET_POD_LOG_DIR`，如果当前 Kubernetes/kubelet 版本支持对应配置项。

kubelet 参数示例：

```text
--root-dir=${KUBELET_ROOT_DIR}
```

### 7.7 kubeadm 初始化

生成 kubeadm 配置：

```yaml
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
kubernetesVersion: v1.35.5
imageRepository: ${K8S_IMAGE_REPO}
networking:
  podSubnet: 10.244.0.0/16
  serviceSubnet: 10.96.0.0/12
etcd:
  local:
    dataDir: ${ETCD_DATA_DIR}
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
rootDir: ${KUBELET_ROOT_DIR}
podLogsDir: ${KUBELET_POD_LOG_DIR}
```

执行：

```bash
kubeadm init --config /tmp/kubeadm-config.yaml
```

### 7.8 配置 kubectl

写入：

- `/root/.kube/config`
- 如果通过 sudo 执行，也写入原用户的 `$HOME/.kube/config`

### 7.9 安装 Calico

要求：

- 默认模式可以使用官方 manifest 或本地固定 manifest。
- `CN=1` 时必须使用本地已改写 manifest，不在安装阶段访问 GitHub。
- 本地 manifest 存储在 `K8S_MANIFEST_DIR`。
- Pod CIDR 必须与 kubeadm 的 `podSubnet` 一致。
- `REWRITE_IMAGES=true` 时所有 Calico 镜像必须已改写为 `IMAGE_MIRROR_PREFIX` 前缀。

### 7.10 安装 metrics-server

要求：

- 默认模式可以使用官方 manifest 或本地固定 manifest。
- 本地 manifest 存储在 `K8S_MANIFEST_DIR`。
- `REWRITE_IMAGES=true` 时镜像必须已改写为 `IMAGE_MIRROR_PREFIX` 前缀。
- 单节点 kubeadm 环境默认加入：

```text
--kubelet-insecure-tls
--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
```

### 7.11 安装 Traefik

要求：

- 默认模式可以使用官方 manifest 或本地固定 manifest。
- `CN=1` 时必须使用本地 manifest，不在安装阶段访问 GitHub。
- 本地 manifest 存储在 `K8S_MANIFEST_DIR`。
- 启用 Kubernetes Ingress Provider。
- 创建默认 `IngressClass: traefik`。
- 默认暴露为 NodePort：
  - HTTP：`30080`
  - HTTPS：`30443`
- `REWRITE_IMAGES=true` 时所有镜像必须已改写为 `IMAGE_MIRROR_PREFIX` 前缀。
- 不默认开启 dashboard 对外暴露。需要时通过配置项显式启用。

### 7.12 配置本地 PV/PVC 存储根目录

第一版不默认安装复杂的分布式存储，但要预留本地 PV/PVC 目录能力。

默认目录：

```text
K8S_LOCAL_PV_ROOT="${K8S_DATA_ROOT}/local-pv"
K8S_PVC_ROOT="${K8S_DATA_ROOT}/pvc"
```

要求：

- 创建 `K8S_LOCAL_PV_ROOT` 和 `K8S_PVC_ROOT`。
- smoke test 或示例 PV 使用 `K8S_LOCAL_PV_ROOT`。
- 如果后续接入 local-path-provisioner，默认数据目录使用 `K8S_PVC_ROOT`。
- 不把业务 PV/PVC 数据放到 `/tmp`、安装包临时目录或脚本目录。

### 7.13 允许单节点调度业务 Pod

执行：

```bash
kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true
kubectl taint nodes --all node-role.kubernetes.io/master- || true
```

## 8. 证书自动续期

第一版必须包含 kubeadm 证书自动续期。

安装内容：

```text
/usr/local/sbin/k8s-cert-renew
/etc/systemd/system/k8s-cert-renew.service
/etc/systemd/system/k8s-cert-renew.timer
```

策略：

- 每月执行一次检查。
- 如果任意 kubeadm 管理的证书剩余有效期小于 `90` 天，则续期。
- 续期前备份：

```text
/etc/kubernetes/pki
/etc/kubernetes/*.conf
```

- 执行：

```bash
kubeadm certs renew all
```

- 续期后重启控制面静态 Pod：
  - `kube-apiserver`
  - `kube-controller-manager`
  - `kube-scheduler`
  - `etcd`
- 更新 kubeconfig：
  - `/root/.kube/config`
  - sudo 原用户的 kubeconfig，如果存在
- 日志写入：

```text
/var/log/k8s-cert-renew.log
```

手动命令：

```bash
k8s-cert-renew --check
k8s-cert-renew --renew
```

## 9. 文件结构

```text
base-software-installer/
  README.md
  standards/
    script-style.md             # 所有安装脚本的编写规范
    logging.md                  # 日志与步骤状态规范
    release.md                  # 发布包与校验规范
  templates/
    common/
      env.sh                    # 可复制到各软件目录的公共模板
      log.sh
      steps.sh
      download.sh
      os.sh
      prompt.sh
  k8s/
    install.sh                  # Kubernetes 独立安装脚本
    config.env
    scripts/
      00-common.sh
      01-detect.sh
      02-os-init.sh
      03-data-dirs.sh
      04-containerd.sh
      05-kubernetes-packages.sh
      06-kubeadm-init.sh
      07-calico.sh
      08-metrics-server.sh
      09-traefik.sh
      10-single-node.sh
      11-cert-renew.sh
      12-verify.sh
    manifests/
      calico.yaml
      metrics-server.yaml
      traefik.yaml
      traefik-ingressclass.yaml
      examples/
        ingress-smoke-test.yaml
    tools/
      sync-manifests.sh
      audit-images.sh
      rewrite-images.sh
      check-domains.sh
    release/
      urls.env                  # Kubernetes 专属发布地址配置
      SHA256SUMS
    README.md
  docker/
    README.md                   # 后续软件目录预留
    install.sh                  # Docker 独立安装脚本，后续实现
    config.env
    scripts/
    tools/
    release/
  releases/
    k8s/
    docker/
```

说明：

- 当前第一版实现 `k8s/`。
- 后续新增 Docker 时放到 `docker/`，不混入 Kubernetes 脚本。
- 每个软件目录都有自己的 `install.sh`，一个脚本只安装一个软件。
- `templates/common/` 只作为公共模板来源，各软件可以复制或引用，但不作为运行时总入口。
- `standards/` 维护项目规范，保证不同软件脚本的日志、参数、发布方式一致。
- `releases/` 只存放各软件发布产物或发布索引，不代表统一安装入口。

## 10. 维护阶段 manifest 处理

维护者执行：

```bash
./k8s/tools/sync-manifests.sh
./k8s/tools/audit-images.sh k8s/manifests/
./k8s/tools/rewrite-images.sh k8s/manifests/
./k8s/tools/check-domains.sh
```

要求：

- `sync-manifests.sh` 可以访问 GitHub 等上游，但只在维护阶段使用。
- 默认模式下，`install.sh` 可以访问官方地址；但仍建议优先使用包内固定 manifest，保证可重复安装。
- `CN=1` 时，`install.sh` 不允许访问 GitHub。
- `audit-images.sh` 必须列出所有镜像。
- `rewrite-images.sh` 必须支持通过 `IMAGE_MIRROR_PREFIX` 将镜像改写为指定前缀。
- `check-domains.sh` 必须支持默认模式和 `CN=1` 两套域名规则。
- `CN=1` 时，`check-domains.sh` 必须确认安装阶段会访问的 URL 域名都在中国大陆可访问白名单内。

## 11. 安装完成验证

安装结束后检查：

```bash
kubectl get nodes -o wide
kubectl get pods -A
kubectl top nodes
kubectl get ingressclass
kubectl get svc -n traefik
kubectl get ingress -A
systemctl list-timers | grep k8s-cert-renew
```

成功输出应包含：

```text
Kubernetes: v1.35.5
Mode: CN=0
Rewrite images: false
Runtime: containerd
CNI: Calico
metrics-server: Ready
Ingress Controller: Traefik
IngressClass: traefik
Traefik HTTP NodePort: 30080
Traefik HTTPS NodePort: 30443
Single-node scheduling: enabled
Certificate auto-renew: enabled
Kubeconfig: /root/.kube/config
Data root: /var/lib/k8s-installer-data
containerd root: /var/lib/k8s-installer-data/containerd/root
kubelet root: /var/lib/k8s-installer-data/kubelet
etcd data: /var/lib/k8s-installer-data/etcd
Pod logs: /var/lib/k8s-installer-data/logs/pods
Local PV root: /var/lib/k8s-installer-data/local-pv
PVC root: /var/lib/k8s-installer-data/pvc
```

## 12. 第一版细化实现方案

### 12.1 分发形态

Kubernetes 第一版建议采用“独立入口脚本 + Kubernetes 专属 tar 包”的方式：

```text
https://k8s-install.example.cn/install.sh
https://k8s-install.example.cn/releases/k8s-installer-v1.0.0-linux-amd64.tar.gz
https://k8s-install.example.cn/releases/k8s-installer-v1.0.0-linux-arm64.tar.gz
https://k8s-install.example.cn/releases/k8s-installer-v1.0.0-linux-amd64-cn.tar.gz
https://k8s-install.example.cn/releases/k8s-installer-v1.0.0-linux-arm64-cn.tar.gz
https://k8s-install.example.cn/releases/SHA256SUMS
```

`k8s/install.sh` 对外发布为 `https://k8s-install.example.cn/install.sh`，只安装 Kubernetes。它只做最小工作：

- 检测系统架构。
- 根据 `CN=1` 选择普通 tar 包或 cn tar 包。
- 默认模式从主站下载，`CN=1` 从中国大陆可访问 CDN 下载。
- 校验 SHA256。
- 解压到临时目录。
- 执行包内真正的安装入口。

这样可以避免把大量 manifest 和脚本塞进单个 shell，也便于版本化和回滚。

### 12.2 交互与无人值守行为

默认行为是交互式安装。通过 `curl ... | sh` 执行时，脚本应展示关键配置并让用户确认或输入：

- 是否启用中国模式：`CN=1`
- Kubernetes 版本
- Pod CIDR
- Service CIDR
- 数据根目录：`K8S_DATA_ROOT`
- containerd 存储目录
- kubelet 数据目录
- etcd 数据目录
- PV/PVC 根目录
- 是否安装 metrics-server
- 是否安装 Traefik
- 是否启用证书自动续期

用户也可以通过环境变量直接执行无人值守安装：

```bash
curl -fsSL https://k8s-install.example.cn/install.sh | \
  ASSUME_YES=1 CN=1 K8S_DATA_ROOT=/data/kubernetes sh
```

无人值守模式触发条件：

- `ASSUME_YES=1`
- 或所有关键配置都已通过环境变量传入，并设置 `NON_INTERACTIVE=1`

无人值守模式要求：

- 不能出现交互确认。
- 缺少前置条件时直接失败并输出明确原因。
- 检测到网段冲突时直接失败。
- 检测到已有异常 Kubernetes 残留时直接失败，不自动 reset。
- 检测到软件源没有 `1.35.5` 时直接失败。

交互模式下，用户可以修改默认值；但任何破坏性操作仍然不能默认执行。

### 12.3 支持系统

第一版优先支持：

- Ubuntu 22.04 / 24.04
- Debian 12
- Rocky Linux 9
- AlmaLinux 9

CentOS 7、Ubuntu 20.04、Debian 11 可以作为兼容目标，但不作为第一优先级。原因是 Kubernetes `v1.35.5` 对较老系统、内核和软件源的兼容性风险更高。

### 12.4 软件源策略

Debian/Ubuntu：

- 默认模式使用官方或发行版默认 apt 源。
- 默认模式 Kubernetes 包源使用官方源。
- `CN=1` 时 apt 源使用中国大陆镜像。
- `CN=1` 时 Kubernetes 包源使用中国大陆可访问镜像。
- containerd 默认优先使用发行版源；`CN=1` 时可使用 Docker CE 国内镜像源中的 containerd.io。

RHEL/Rocky/Alma：

- 默认模式使用官方或发行版默认 yum/dnf 源。
- 默认模式 Kubernetes 包源使用官方源。
- `CN=1` 时 yum/dnf 源使用中国大陆镜像。
- `CN=1` 时 containerd 可使用国内 Docker CE repo。
- `CN=1` 时 Kubernetes 包源使用中国大陆可访问镜像。

安装脚本不修改用户已有源文件为不可逆状态。需要新增 repo 时单独写入：

```text
/etc/apt/sources.list.d/k8s-installer*.list
/etc/yum.repos.d/k8s-installer*.repo
```

### 12.5 Traefik 安装细节

第一版使用静态 manifest 安装 Traefik，不依赖安装阶段执行 Helm。

原因：

- 减少安装阶段对 Helm repo 的网络依赖。
- 方便提前审计和改写镜像。
- 方便固定版本，保证重复安装结果一致。

Traefik 部署要求：

- Namespace：`traefik`
- Deployment：`traefik`
- Service：`traefik`
- Service Type：`NodePort`
- IngressClass：`traefik`
- HTTP NodePort：`30080`
- HTTPS NodePort：`30443`
- 默认不开启 dashboard 对外访问。
- readinessProbe 和 livenessProbe 必须保留。
- resources 必须设置基本 requests/limits，避免单节点资源失控。

默认参数：

```text
--providers.kubernetesingress=true
--providers.kubernetesingress.ingressclass=traefik
--entrypoints.web.address=:80
--entrypoints.websecure.address=:443
--ping=true
--metrics.prometheus=true
```

后续可选增强：

- 开启 Traefik Gateway API provider。
- 安装 Envoy Gateway 作为替代控制器。
- 接入 cert-manager。

### 12.6 验证用例

安装结束后可以创建一个临时 smoke test：

- `Deployment: k8s-smoke-nginx`
- `Service: k8s-smoke-nginx`
- `Ingress: k8s-smoke-nginx`
- `host: smoke.local`

验证：

```bash
curl -H 'Host: smoke.local' http://127.0.0.1:30080/
```

成功后删除 smoke test 资源。默认执行 smoke test，失败则安装整体判定失败；交互模式下可提示用户是否保留 smoke test 资源用于排查。

### 12.7 Envoy Gateway 后续可选项

第二版可以增加：

```bash
INGRESS_CONTROLLER="envoy-gateway"
```

安装内容：

- Gateway API CRD
- Envoy Gateway controller
- 默认 `GatewayClass`
- 默认 `Gateway`
- NodePort 暴露方式

但第一版不实现，避免给使用者增加 Gateway API 学习成本。

### 12.8 脚本模块职责

`00-common.sh`：

- 日志函数。
- 错误处理。
- 命令存在性检查。
- URL 下载函数，按 `CN=1` 选择官方地址或中国大陆镜像地址。
- 镜像改写函数。
- 统一的 `kubectl` 包装函数。
- 步骤执行包装函数，统一记录开始、成功、失败和退出码。

`01-detect.sh`：

- 检测 OS、版本、架构。
- 检测 root/sudo。
- 检测已有 Kubernetes 状态。
- 检测已有 containerd 状态。
- 检测网段冲突。
- 默认模式检测官方域名连通性。
- `CN=1` 时检测中国大陆镜像域名连通性。

`02-os-init.sh`：

- 关闭 swap。
- 写入 sysctl。
- 加载内核模块。
- 处理 SELinux。
- 输出防火墙端口提示。

`03-data-dirs.sh`：

- 创建 `K8S_DATA_ROOT` 及所有子目录。
- 检查目录权限。
- 检查目录所在文件系统可用空间。
- 记录实际使用的数据目录到状态文件。
- 不清空任何已有目录。

`04-containerd.sh`：

- 安装 containerd。
- 生成 containerd 配置。
- 设置 `SystemdCgroup = true`。
- 配置 pause 镜像。
- 设置 `CONTAINERD_ROOT_DIR` 和 `CONTAINERD_STATE_DIR`。
- 重启并验证 CRI。

`05-kubernetes-packages.sh`：

- 默认模式配置官方 Kubernetes 软件源。
- `CN=1` 时配置中国大陆可访问 Kubernetes 软件源。
- 安装固定版本 kubeadm、kubelet、kubectl。
- 锁定版本。
- 启用 kubelet。
- 配置 kubelet 使用 `KUBELET_ROOT_DIR`。
- 如版本支持，配置 kubelet 使用 `KUBELET_POD_LOG_DIR`。

`06-kubeadm-init.sh`：

- 生成 kubeadm config。
- 配置 etcd 使用 `ETCD_DATA_DIR`。
- 执行 `kubeadm init`。
- 配置 kubeconfig。
- 等待 apiserver 可用。

`07-calico.sh`：

- 默认模式应用官方或包内固定 Calico manifest。
- `REWRITE_IMAGES=true` 时应用已改写的 Calico manifest。
- 等待 Calico Pod Ready。
- 验证 CoreDNS 恢复。

`08-metrics-server.sh`：

- 默认模式应用官方或包内固定 metrics-server manifest。
- `REWRITE_IMAGES=true` 时应用已改写的 metrics-server manifest。
- 等待 Deployment Ready。
- 验证 `kubectl top nodes`。

`09-traefik.sh`：

- 默认模式应用官方或包内固定 Traefik manifest。
- `REWRITE_IMAGES=true` 时应用已改写的 Traefik manifest。
- 创建或确认 `IngressClass: traefik`。
- 等待 Traefik Ready。
- 检查 NodePort 是否为预期值。

`10-single-node.sh`：

- 移除 control-plane/master taint。
- 验证普通业务 Pod 可调度。

`11-cert-renew.sh`：

- 安装 `k8s-cert-renew` 命令。
- 安装 systemd service 和 timer。
- 执行首次证书状态检查。

`12-verify.sh`：

- 汇总集群状态。
- 执行 smoke test。
- 输出最终安装结果。

### 12.9 日志与状态文件

安装过程必须记录每一步操作。任何失败必须记录失败步骤、失败命令、退出码、开始时间、结束时间和关键输出。

安装日志：

```text
/var/log/k8s-installer.log
/var/log/k8s-installer-steps.jsonl
```

安装状态：

```text
/var/lib/k8s-installer/state.env
/var/lib/k8s-installer/steps/
```

状态文件记录：

```bash
K8S_VERSION="1.35.5"
ASSUME_YES="0"
NON_INTERACTIVE="0"
CN="0"
IMAGE_MIRROR_PREFIX="swr.cn-north-4.myhuaweicloud.com/ddn-k8s"
REWRITE_IMAGES="false"
CNI="calico"
INGRESS_CONTROLLER="traefik"
INSTALL_TIME="..."
POD_CIDR="10.244.0.0/16"
SERVICE_CIDR="10.96.0.0/12"
K8S_DATA_ROOT="/var/lib/k8s-installer-data"
CONTAINERD_ROOT_DIR="/var/lib/k8s-installer-data/containerd/root"
CONTAINERD_STATE_DIR="/var/lib/k8s-installer-data/containerd/state"
KUBELET_ROOT_DIR="/var/lib/k8s-installer-data/kubelet"
KUBELET_POD_LOG_DIR="/var/lib/k8s-installer-data/logs/pods"
ETCD_DATA_DIR="/var/lib/k8s-installer-data/etcd"
K8S_MANIFEST_DIR="/var/lib/k8s-installer-data/manifests"
K8S_RESOURCE_DIR="/var/lib/k8s-installer-data/resources"
K8S_LOCAL_PV_ROOT="/var/lib/k8s-installer-data/local-pv"
K8S_PVC_ROOT="/var/lib/k8s-installer-data/pvc"
```

每个步骤写入独立状态文件：

```text
/var/lib/k8s-installer/steps/01-detect.status
/var/lib/k8s-installer/steps/02-os-init.status
/var/lib/k8s-installer/steps/03-data-dirs.status
/var/lib/k8s-installer/steps/04-containerd.status
```

状态值：

```text
PENDING
RUNNING
SUCCESS
SKIPPED
FAILED
```

JSONL 日志示例：

```json
{"time":"2026-06-16T15:20:01+08:00","step":"04-containerd","status":"RUNNING","message":"install containerd"}
{"time":"2026-06-16T15:20:32+08:00","step":"04-containerd","status":"SUCCESS","duration_sec":31}
{"time":"2026-06-16T15:21:10+08:00","step":"05-kubernetes-packages","status":"FAILED","exit_code":1,"command":"apt-get install kubeadm=1.35.5-00","log":"/var/log/k8s-installer.log"}
```

命令执行必须通过统一包装函数，例如：

```bash
run_step "04-containerd" install_containerd
run_cmd "04-containerd" apt-get install -y containerd.io
```

要求：

- `run_step` 负责记录步骤开始、成功、跳过、失败。
- `run_cmd` 负责记录命令、退出码和 stderr/stdout 摘要。
- 日志中必须包含当前模式：`CN=0` 或 `CN=1`。
- 日志中必须包含镜像前缀：`IMAGE_MIRROR_PREFIX`。
- 日志中必须包含安装包版本和 SHA256 校验结果。

重复执行时，脚本优先读取真实系统状态，不只依赖状态文件。状态文件只作为辅助信息。

### 12.10 失败处理原则

第一版不自动执行破坏性恢复：

- 不自动执行 `kubeadm reset`。
- 不自动删除 `/etc/kubernetes`。
- 不自动删除 `/var/lib/etcd`。
- 不自动清空 iptables。
- 不自动删除用户已有 CNI 配置。

失败后输出：

- 失败步骤。
- 失败命令。
- 命令退出码。
- 关键日志路径。
- 最近 30 行错误日志摘要。
- 当前检测到的组件状态。
- 建议人工处理命令。

只有用户后续明确要求实现卸载或清理脚本时，再单独设计 destructive 操作。

### 12.11 端口清单

单节点默认需要关注：

```text
6443/tcp      kube-apiserver
2379-2380/tcp etcd
10250/tcp     kubelet
10257/tcp     kube-controller-manager
10259/tcp     kube-scheduler
30080/tcp     Traefik HTTP NodePort
30443/tcp     Traefik HTTPS NodePort
```

Calico 可能需要：

```text
179/tcp       BGP，默认单节点通常不需要对外开放
4789/udp      VXLAN，取决于 Calico 封装模式
```

第一版不默认关闭防火墙。检测到防火墙启用时输出端口清单和当前风险，由用户或上层自动化决定是否放行。

### 12.12 版本固定策略

所有组件版本都必须显式固定：

```bash
K8S_VERSION="1.35.5"
CALICO_VERSION="固定值"
METRICS_SERVER_VERSION="固定值"
TRAEFIK_VERSION="固定值"
```

维护者升级版本时必须执行：

```bash
./tools/sync-manifests.sh
./tools/audit-images.sh manifests/
./tools/rewrite-images.sh manifests/
./tools/check-domains.sh
```

版本升级不在最终用户安装阶段自动发生。

## 13. 第一版不做的能力

第一版暂不包含：

- 多节点 join
- HA control-plane
- 完全离线安装包
- Kubernetes 自动升级
- 卸载脚本
- Envoy Gateway 默认安装
- 云厂商 LoadBalancer 集成

这些能力可以作为第二版扩展。

## 14. 参考来源

- Kubernetes Releases: https://kubernetes.io/releases/
- Kubernetes kubeadm certificate management: https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/
- Envoy Gateway: https://gateway.envoyproxy.io/
- Traefik Kubernetes Gateway API: https://doc.traefik.io/traefik/reference/install-configuration/providers/kubernetes/kubernetes-gateway/
- Traefik Kubernetes Ingress: https://doc.traefik.io/traefik/reference/install-configuration/providers/kubernetes/kubernetes-ingress/
- ingress-nginx retirement notice: https://kubernetes.github.io/ingress-nginx/
