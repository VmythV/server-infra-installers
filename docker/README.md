# Docker Installer

Independent Docker Engine installer.

Default interactive install:

```bash
./install.sh
```

China mainland mode:

```bash
CN=1 ./install.sh
```

Unattended example:

```bash
ASSUME_YES=1 CN=1 DOCKER_DATA_ROOT=/data/docker ./install.sh
```

It installs:

- Docker Engine
- Docker CLI
- containerd.io
- Docker Buildx plugin
- Docker Compose plugin

Key environment variables:

```bash
DOCKER_DATA_ROOT=/data/docker
DOCKER_REGISTRY_MIRRORS=https://mirror.example.com
CN=1
ASSUME_YES=1
```

Build release packages:

```bash
./tools/build-release.sh
```
