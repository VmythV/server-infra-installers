# Base Software Installers

Project-managed one-click installers for infrastructure software.

This repository does **not** provide a single installer that installs everything. Each software product has its own directory, installer script, release artifacts, and public install URL.

The first supported installers are Kubernetes and Docker. More installers can be added later as independent software directories.

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

## Install Docker

Default interactive install:

```bash
curl -fsSL https://docker-install.example.cn/install.sh | sh
```

China mainland network mode:

```bash
curl -fsSL https://docker-install.example.cn/install.sh | CN=1 sh
```

Unattended example:

```bash
curl -fsSL https://docker-install.example.cn/install.sh | ASSUME_YES=1 CN=1 DOCKER_DATA_ROOT=/data/docker sh
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
├── docker/                 # Docker installer
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

## Docker Development

Build Docker release packages:

```bash
./docker/tools/build-release.sh
```

Important Docker environment variables:

```bash
DOCKER_DATA_ROOT=/data/docker
DOCKER_REGISTRY_MIRRORS=https://mirror.example.com
CN=1
ASSUME_YES=1
```

For Docker, image acceleration uses Docker daemon registry mirrors. Set `DOCKER_REGISTRY_MIRRORS` to a comma-separated list when your network requires it.

## Kubernetes Release for China Mainland

Before publishing a China-ready Kubernetes installer, generate local manifests and rewrite all container images to a China-accessible mirror.

1. Sync upstream manifests:

```bash
./k8s/tools/sync-manifests.sh
```

2. Rewrite images:

```bash
IMAGE_MIRROR_PREFIX=swr.cn-north-4.myhuaweicloud.com/ddn-k8s \
  ./k8s/tools/rewrite-images.sh k8s/manifests/
```

3. Verify China mode manifests:

```bash
CN=1 ./k8s/tools/check-domains.sh k8s
```

4. Build release artifacts:

```bash
K8S_INSTALLER_VERSION=v1.0.0 ./k8s/tools/build-release.sh
```

The generated files are written to:

```text
releases/k8s/
├── SHA256SUMS
├── k8s-installer-v1.0.0-linux-amd64.tar.gz
├── k8s-installer-v1.0.0-linux-arm64.tar.gz
├── k8s-installer-v1.0.0-linux-amd64-cn.tar.gz
└── k8s-installer-v1.0.0-linux-arm64-cn.tar.gz
```

## Publishing to OSS / CDN

Upload the following files:

```text
k8s/install.sh
releases/k8s/SHA256SUMS
releases/k8s/k8s-installer-v1.0.0-linux-amd64.tar.gz
releases/k8s/k8s-installer-v1.0.0-linux-arm64.tar.gz
releases/k8s/k8s-installer-v1.0.0-linux-amd64-cn.tar.gz
releases/k8s/k8s-installer-v1.0.0-linux-arm64-cn.tar.gz
```

Recommended OSS / CDN layout:

```text
https://k8s-install.example.cn/install.sh
https://k8s-install.example.cn/releases/SHA256SUMS
https://k8s-install.example.cn/releases/k8s-installer-v1.0.0-linux-amd64.tar.gz
https://k8s-install.example.cn/releases/k8s-installer-v1.0.0-linux-arm64.tar.gz
https://k8s-install.example.cn/releases/k8s-installer-v1.0.0-linux-amd64-cn.tar.gz
https://k8s-install.example.cn/releases/k8s-installer-v1.0.0-linux-arm64-cn.tar.gz
```

The path matters. `k8s/install.sh` defaults to:

```text
RELEASE_BASE_URL=https://k8s-install.example.cn/releases
```

If you publish to a different domain or path, run the installer with:

```bash
curl -fsSL https://your-oss.example.com/k8s/install.sh | \
  RELEASE_BASE_URL=https://your-oss.example.com/k8s/releases sh
```

China mainland install after publishing:

```bash
curl -fsSL https://k8s-install.example.cn/install.sh | CN=1 sh
```

Unattended China mainland install:

```bash
curl -fsSL https://k8s-install.example.cn/install.sh | \
  ASSUME_YES=1 CN=1 K8S_DATA_ROOT=/data/kubernetes sh
```

## Docker Release and Publishing

Build Docker release artifacts:

```bash
DOCKER_INSTALLER_VERSION=v1.0.0 ./docker/tools/build-release.sh
```

The generated files are written to:

```text
releases/docker/
├── SHA256SUMS
├── docker-installer-v1.0.0-linux-amd64.tar.gz
├── docker-installer-v1.0.0-linux-arm64.tar.gz
├── docker-installer-v1.0.0-linux-amd64-cn.tar.gz
└── docker-installer-v1.0.0-linux-arm64-cn.tar.gz
```

Upload the following files:

```text
docker/install.sh
releases/docker/SHA256SUMS
releases/docker/docker-installer-v1.0.0-linux-amd64.tar.gz
releases/docker/docker-installer-v1.0.0-linux-arm64.tar.gz
releases/docker/docker-installer-v1.0.0-linux-amd64-cn.tar.gz
releases/docker/docker-installer-v1.0.0-linux-arm64-cn.tar.gz
```

Recommended OSS / CDN layout:

```text
https://docker-install.example.cn/install.sh
https://docker-install.example.cn/releases/SHA256SUMS
https://docker-install.example.cn/releases/docker-installer-v1.0.0-linux-amd64.tar.gz
https://docker-install.example.cn/releases/docker-installer-v1.0.0-linux-arm64.tar.gz
https://docker-install.example.cn/releases/docker-installer-v1.0.0-linux-amd64-cn.tar.gz
https://docker-install.example.cn/releases/docker-installer-v1.0.0-linux-arm64-cn.tar.gz
```

If you publish to a different domain or path, run the installer with:

```bash
curl -fsSL https://your-oss.example.com/docker/install.sh | \
  RELEASE_BASE_URL=https://your-oss.example.com/docker/releases CN=1 sh
```

## Project Guidelines

Use these rules when adding or changing installers in this repository.

### Repository Scope

- This repository manages installer projects; it is not a single all-in-one installer.
- One software product must have one independent directory and one independent `install.sh`.
- Each software product must be independently published and accessed through its own URL.
- Do not add a root script that installs multiple products.
- Shared code belongs in `templates/` or `standards/`; runtime installation should stay inside each software directory.

### Installer Behavior

- Default mode must be interactive.
- Unattended mode must be explicitly enabled with environment variables such as `ASSUME_YES=1` or `NON_INTERACTIVE=1`.
- All important options must be overridable by environment variables.
- The installer must be idempotent: if the software is already installed and healthy, it should skip destructive work.
- Do not run destructive cleanup by default. Commands such as `kubeadm reset`, deleting data directories, clearing iptables, or removing user files require an explicit future cleanup command or confirmation.

### China Mainland Support

- Default mode should use official upstream sources and images.
- `CN=1` must switch to China-accessible package sources, download URLs, and image rewrite behavior.
- Image rewrite must be controlled by `REWRITE_IMAGES=true` or `CN=1`.
- The mirror prefix must be configurable with `IMAGE_MIRROR_PREFIX`.
- Before publishing CN artifacts, run image audit, image rewrite, and domain checks.
- Runtime install in `CN=1` mode must not depend on GitHub, `raw.githubusercontent.com`, `registry.k8s.io`, `docker.io`, `quay.io`, `ghcr.io`, `gcr.io`, or `k8s.gcr.io`.

### Data and Storage

- Installers must support custom data roots, for example `K8S_DATA_ROOT`.
- Different data types must be stored in separate subdirectories.
- For Kubernetes, containerd image storage, containerd state, kubelet data, etcd data, Pod logs, manifests, resources, backups, PV roots, and PVC roots must be configurable.
- Installers must not write workload data into `/tmp` or the script directory.

### Logging and Failure Records

- Every step must be logged.
- Failures must record the step name, command, exit code, start/end time, and log path.
- Use a normal log file and a structured step log, such as JSONL.
- Keep state files under `/var/lib/<software>-installer/`.

### Release and OSS / CDN

- Release packages must include SHA256 checksums.
- The public `install.sh` must be uploaded together with release tarballs and `SHA256SUMS`.
- OSS / CDN paths must match the installer `RELEASE_BASE_URL`, or users must override `RELEASE_BASE_URL` at runtime.
- Generated release artifacts should not be committed to Git unless there is a specific reason.

### Shell and Compatibility

- Prefer POSIX `sh` for installer scripts.
- Keep scripts readable and split large workflows into step scripts.
- Support common server distributions first, then expand compatibility deliberately.
- Avoid hidden network access. Downloads must be visible in config or release docs.

## Logs

Kubernetes installer logs:

```text
/var/log/k8s-installer.log
/var/log/k8s-installer-steps.jsonl
/var/lib/k8s-installer/state.env
/var/lib/k8s-installer/steps/
```

Docker installer logs:

```text
/var/log/docker-installer.log
/var/log/docker-installer-steps.jsonl
/var/lib/docker-installer/state.env
/var/lib/docker-installer/steps/
```

## 中文说明

本仓库用于以项目管理方式维护基础软件的一键安装脚本。

注意：这里不是“一个脚本安装所有软件”。每个软件都有独立目录、独立安装脚本、独立发布包和独立访问地址。

当前已实现 Kubernetes 单节点安装脚本和 Docker 安装脚本，后续可以继续添加其他软件。

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

### Docker 安装

默认交互式安装：

```bash
curl -fsSL https://docker-install.example.cn/install.sh | sh
```

中国大陆网络环境：

```bash
curl -fsSL https://docker-install.example.cn/install.sh | CN=1 sh
```

无人值守示例：

```bash
curl -fsSL https://docker-install.example.cn/install.sh | ASSUME_YES=1 CN=1 DOCKER_DATA_ROOT=/data/docker sh
```

Docker 的镜像加速使用 Docker daemon 的 registry mirrors，不使用 Kubernetes 镜像前缀规则。需要时通过 `DOCKER_REGISTRY_MIRRORS` 配置，多个地址用英文逗号分隔。

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

### 生成中国大陆可用的 Release 产物

发布中国大陆可用版本前，需要先同步 manifest，并把所有容器镜像改写到中国大陆可访问的镜像前缀。

1. 同步上游 manifest：

```bash
./k8s/tools/sync-manifests.sh
```

2. 改写镜像：

```bash
IMAGE_MIRROR_PREFIX=swr.cn-north-4.myhuaweicloud.com/ddn-k8s \
  ./k8s/tools/rewrite-images.sh k8s/manifests/
```

3. 检查国内模式：

```bash
CN=1 ./k8s/tools/check-domains.sh k8s
```

4. 构建发布包：

```bash
K8S_INSTALLER_VERSION=v1.0.0 ./k8s/tools/build-release.sh
```

生成目录：

```text
releases/k8s/
├── SHA256SUMS
├── k8s-installer-v1.0.0-linux-amd64.tar.gz
├── k8s-installer-v1.0.0-linux-arm64.tar.gz
├── k8s-installer-v1.0.0-linux-amd64-cn.tar.gz
└── k8s-installer-v1.0.0-linux-arm64-cn.tar.gz
```

### 上传到 OSS / CDN

需要上传：

```text
k8s/install.sh
releases/k8s/SHA256SUMS
releases/k8s/k8s-installer-v1.0.0-linux-amd64.tar.gz
releases/k8s/k8s-installer-v1.0.0-linux-arm64.tar.gz
releases/k8s/k8s-installer-v1.0.0-linux-amd64-cn.tar.gz
releases/k8s/k8s-installer-v1.0.0-linux-arm64-cn.tar.gz
```

推荐上传后的路径：

```text
https://k8s-install.example.cn/install.sh
https://k8s-install.example.cn/releases/SHA256SUMS
https://k8s-install.example.cn/releases/k8s-installer-v1.0.0-linux-amd64.tar.gz
https://k8s-install.example.cn/releases/k8s-installer-v1.0.0-linux-arm64.tar.gz
https://k8s-install.example.cn/releases/k8s-installer-v1.0.0-linux-amd64-cn.tar.gz
https://k8s-install.example.cn/releases/k8s-installer-v1.0.0-linux-arm64-cn.tar.gz
```

路径需要和 `k8s/install.sh` 中默认的 `RELEASE_BASE_URL` 匹配：

```text
RELEASE_BASE_URL=https://k8s-install.example.cn/releases
```

如果你上传到其他路径，执行时覆盖 `RELEASE_BASE_URL`：

```bash
curl -fsSL https://your-oss.example.com/k8s/install.sh | \
  RELEASE_BASE_URL=https://your-oss.example.com/k8s/releases CN=1 sh
```

上传完成后，中国大陆环境即可执行：

```bash
curl -fsSL https://k8s-install.example.cn/install.sh | CN=1 sh
```

### Docker Release 和上传

构建 Docker 发布包：

```bash
DOCKER_INSTALLER_VERSION=v1.0.0 ./docker/tools/build-release.sh
```

生成目录：

```text
releases/docker/
├── SHA256SUMS
├── docker-installer-v1.0.0-linux-amd64.tar.gz
├── docker-installer-v1.0.0-linux-arm64.tar.gz
├── docker-installer-v1.0.0-linux-amd64-cn.tar.gz
└── docker-installer-v1.0.0-linux-arm64-cn.tar.gz
```

需要上传：

```text
docker/install.sh
releases/docker/SHA256SUMS
releases/docker/docker-installer-v1.0.0-linux-amd64.tar.gz
releases/docker/docker-installer-v1.0.0-linux-arm64.tar.gz
releases/docker/docker-installer-v1.0.0-linux-amd64-cn.tar.gz
releases/docker/docker-installer-v1.0.0-linux-arm64-cn.tar.gz
```

推荐上传后的路径：

```text
https://docker-install.example.cn/install.sh
https://docker-install.example.cn/releases/SHA256SUMS
https://docker-install.example.cn/releases/docker-installer-v1.0.0-linux-amd64.tar.gz
https://docker-install.example.cn/releases/docker-installer-v1.0.0-linux-arm64.tar.gz
https://docker-install.example.cn/releases/docker-installer-v1.0.0-linux-amd64-cn.tar.gz
https://docker-install.example.cn/releases/docker-installer-v1.0.0-linux-arm64-cn.tar.gz
```

上传完成后，中国大陆环境即可执行：

```bash
curl -fsSL https://docker-install.example.cn/install.sh | CN=1 sh
```

### 项目编写规范

新增或修改安装脚本时遵循以下规则。

#### 仓库边界

- 本仓库用于管理多个基础软件安装脚本项目，不是一个统一安装所有软件的脚本。
- 一个软件一个独立目录，一个独立 `install.sh`。
- 每个软件独立发布、独立访问、独立安装。
- 不添加根目录总安装入口。
- 公共代码放到 `templates/` 或 `standards/`，实际安装逻辑留在各软件目录中。

#### 安装行为

- 默认必须支持交互式安装。
- 无人值守安装必须显式通过环境变量开启，例如 `ASSUME_YES=1` 或 `NON_INTERACTIVE=1`。
- 关键参数必须支持环境变量覆盖。
- 脚本必须幂等：如果软件已经安装且健康，不应重复破坏性安装。
- 默认不执行破坏性清理，例如 `kubeadm reset`、删除数据目录、清空 iptables、删除用户文件等。

#### 国内环境支持

- 默认模式使用官方源、官方地址和官方镜像。
- `CN=1` 启用中国大陆可访问的软件源、下载地址和镜像改写。
- 镜像改写由 `CN=1` 或 `REWRITE_IMAGES=true` 控制。
- 镜像前缀必须可以通过 `IMAGE_MIRROR_PREFIX` 配置。
- 发布国内版本前必须执行镜像审计、镜像改写和域名检查。
- `CN=1` 运行时不能依赖 GitHub、`raw.githubusercontent.com`、`registry.k8s.io`、`docker.io`、`quay.io`、`ghcr.io`、`gcr.io`、`k8s.gcr.io`。

#### 数据目录

- 安装脚本必须支持自定义数据根目录，例如 `K8S_DATA_ROOT`。
- 不同数据类型必须拆分到不同子目录。
- Kubernetes 需要支持自定义 containerd 镜像目录、containerd 状态目录、kubelet 数据目录、etcd 数据目录、Pod 日志目录、manifest 目录、资源目录、备份目录、PV/PVC 根目录。
- 不允许把业务数据写入 `/tmp` 或脚本目录。

#### 日志和失败记录

- 每一步操作都必须记录日志。
- 失败时必须记录步骤名、命令、退出码、开始/结束时间和日志路径。
- 同时保留普通日志和结构化步骤日志。
- 状态文件放到 `/var/lib/<software>-installer/`。

#### 发布规范

- 发布包必须带 SHA256 校验。
- 公开的 `install.sh`、release tar 包和 `SHA256SUMS` 必须一起上传。
- OSS/CDN 路径必须和 `RELEASE_BASE_URL` 匹配，否则执行时必须覆盖 `RELEASE_BASE_URL`。
- 生成的 release tar 包默认不提交到 Git。
