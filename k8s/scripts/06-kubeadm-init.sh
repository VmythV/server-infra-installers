#!/bin/sh

init_kubeadm_cluster() {
  if [ -f /etc/kubernetes/admin.conf ]; then
    log_warn "/etc/kubernetes/admin.conf exists; skip kubeadm init."
    configure_kubeconfig
    return 0
  fi
  mkdir -p "$K8S_RESOURCE_DIR"
  cfg="$K8S_RESOURCE_DIR/kubeadm-config.yaml"
  cat > "$cfg" <<EOF
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
kubernetesVersion: v$K8S_VERSION
imageRepository: $K8S_IMAGE_REPO
networking:
  podSubnet: $POD_CIDR
  serviceSubnet: $SERVICE_CIDR
etcd:
  local:
    dataDir: $ETCD_DATA_DIR
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
rootDir: $KUBELET_ROOT_DIR
podLogsDir: $KUBELET_POD_LOG_DIR
EOF
  run_cmd "06-kubeadm-init" kubeadm init --config "$cfg"
  configure_kubeconfig
}

configure_kubeconfig() {
  mkdir -p /root/.kube
  cp -f /etc/kubernetes/admin.conf /root/.kube/config
  chmod 600 /root/.kube/config
  if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    if [ -n "$user_home" ]; then
      mkdir -p "$user_home/.kube"
      cp -f /etc/kubernetes/admin.conf "$user_home/.kube/config"
      chown -R "$SUDO_USER":"$SUDO_USER" "$user_home/.kube"
    fi
  fi
}
