# Base Software Installers

Project-managed one-click installers for infrastructure software.

This repository does **not** provide a single installer that installs everything. Each software product has its own directory, installer script, release artifacts, and public install URL.

The first supported installer is Kubernetes. More installers, such as Docker, can be added later as independent software directories.

## Install Kubernetes

Default interactive install:

```bash
curl -fsSL https://k8s-install.example.cn/install.sh | sh
```

China mainland network mode:

```bash
curl -fsSL https://k8s-install.example.cn/install.sh | CN=1 sh
```

Unattended example:

```bash
curl -fsSL https://k8s-install.example.cn/install.sh | ASSUME_YES=1 CN=1 K8S_DATA_ROOT=/data/kubernetes sh
```

## What Kubernetes Installs

- Kubernetes `v1.35.5`
- containerd
- kubeadm, kubelet, kubectl
- Calico CNI
- metrics-server
- Traefik Ingress Controller
- Single-node workload scheduling
- kubeadm certificate auto-renewal
- Step-by-step logs and failure records

## Key Features

- One software, one independent `install.sh`.
- Default interactive installation.
- Environment-variable based unattended installation.
- `CN=1` mode for China-accessible package sources and image mirrors.
- Custom image mirror prefix with `IMAGE_MIRROR_PREFIX`.
- Custom Kubernetes data root with `K8S_DATA_ROOT`.
- Structured step logs and installer state files.
- Release package generation with SHA256 checksums.

## Repository Layout

```text
.
├── docker/                 # Docker installer placeholder
├── k8s/                    # Kubernetes installer
│   ├── install.sh
│   ├── config.env
│   ├── scripts/
│   ├── manifests/
│   ├── tools/
│   └── release/
├── releases/               # Generated release artifacts
├── standards/              # Project conventions
└── templates/              # Shared templates for future installers
```

## Kubernetes Development

Audit manifest images:

```bash
./k8s/tools/audit-images.sh k8s/manifests/
```

Rewrite images for China mode:

```bash
IMAGE_MIRROR_PREFIX=swr.cn-north-4.myhuaweicloud.com/ddn-k8s \
  ./k8s/tools/rewrite-images.sh k8s/manifests/
```

Check manifests for China mode:

```bash
CN=1 ./k8s/tools/check-domains.sh k8s
```

Build release packages:

```bash
./k8s/tools/build-release.sh
```

## Logs

Kubernetes installer logs:

```text
/var/log/k8s-installer.log
/var/log/k8s-installer-steps.jsonl
/var/lib/k8s-installer/state.env
/var/lib/k8s-installer/steps/
```

## 中文说明

本仓库用于以项目管理方式维护基础软件的一键安装脚本。

注意：这里不是“一个脚本安装所有软件”。每个软件都有独立目录、独立安装脚本、独立发布包和独立访问地址。

当前已实现 Kubernetes 单节点安装脚本，后续可以继续添加 Docker 等其他软件。

### Kubernetes 安装

默认交互式安装：

```bash
curl -fsSL https://k8s-install.example.cn/install.sh | sh
```

中国大陆网络环境：

```bash
curl -fsSL https://k8s-install.example.cn/install.sh | CN=1 sh
```

无人值守示例：

```bash
curl -fsSL https://k8s-install.example.cn/install.sh | ASSUME_YES=1 CN=1 K8S_DATA_ROOT=/data/kubernetes sh
```

### Kubernetes 安装内容

- Kubernetes `v1.35.5`
- containerd
- kubeadm、kubelet、kubectl
- Calico CNI
- metrics-server
- Traefik Ingress Controller
- 单节点业务 Pod 调度
- kubeadm 证书自动续期
- 步骤日志和失败记录

### 国内模式

设置 `CN=1` 后，脚本会使用中国大陆可访问的软件源、下载地址和镜像改写策略。

默认镜像前缀：

```text
swr.cn-north-4.myhuaweicloud.com/ddn-k8s
```

可通过环境变量覆盖：

```bash
IMAGE_MIRROR_PREFIX=registry.example.cn/k8s-mirror
```
