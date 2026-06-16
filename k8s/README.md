# Kubernetes 单节点安装脚本

默认交互式安装：

```bash
./install.sh
```

中国大陆网络环境：

```bash
CN=1 ./install.sh
```

无人值守：

```bash
ASSUME_YES=1 CN=1 K8S_DATA_ROOT=/data/kubernetes ./install.sh
```

脚本会安装：

- containerd
- kubeadm / kubelet / kubectl
- Kubernetes 单节点 control-plane
- Calico
- metrics-server
- Traefik
- kubeadm 证书自动续期 timer

国内安装前建议维护者先同步并改写 manifest：

```bash
./tools/sync-manifests.sh
./tools/audit-images.sh manifests/
./tools/rewrite-images.sh manifests/
```
