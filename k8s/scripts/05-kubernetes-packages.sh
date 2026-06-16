#!/bin/sh

install_kubernetes_packages() {
  case "$PKG_MANAGER" in
    apt) install_k8s_apt ;;
    dnf|yum) install_k8s_yum ;;
  esac
  configure_kubelet_root
  run_cmd "05-kubernetes-packages" systemctl enable kubelet
}

install_k8s_apt() {
  repo=$K8S_APT_REPO_URL
  [ "$CN" = "1" ] && repo=$CN_K8S_APT_REPO_URL
  run_cmd "05-kubernetes-packages" apt-get update
  run_cmd "05-kubernetes-packages" apt-get install -y ca-certificates curl gnupg apt-transport-https
  mkdir -p /etc/apt/keyrings
  if [ "$CN" = "1" ]; then
    curl -fsSL "${repo}Release.key" | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  else
    curl -fsSL "${repo}Release.key" | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  fi
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] $repo /" > /etc/apt/sources.list.d/k8s-installer-kubernetes.list
  run_cmd "05-kubernetes-packages" apt-get update
  if apt-cache madison kubeadm | grep -q "$K8S_VERSION"; then
    deb_ver=$(apt-cache madison kubeadm | awk -v v="$K8S_VERSION" '$0 ~ v {print $3; exit}')
    run_cmd "05-kubernetes-packages" apt-get install -y "kubelet=$deb_ver" "kubeadm=$deb_ver" "kubectl=$deb_ver"
  else
    die "Kubernetes $K8S_VERSION not found in apt repo $repo"
  fi
  run_cmd "05-kubernetes-packages" apt-mark hold kubelet kubeadm kubectl
}

install_k8s_yum() {
  repo=$K8S_YUM_REPO_URL
  [ "$CN" = "1" ] && repo=$CN_K8S_YUM_REPO_URL
  cat > /etc/yum.repos.d/k8s-installer-kubernetes.repo <<EOF
[kubernetes]
name=Kubernetes
baseurl=$repo
enabled=1
gpgcheck=0
repo_gpgcheck=0
EOF
  run_cmd "05-kubernetes-packages" "$PKG_MANAGER" makecache
  run_cmd "05-kubernetes-packages" "$PKG_MANAGER" install -y "kubelet-$K8S_VERSION" "kubeadm-$K8S_VERSION" "kubectl-$K8S_VERSION"
}

configure_kubelet_root() {
  mkdir -p /etc/systemd/system/kubelet.service.d
  cat > /etc/systemd/system/kubelet.service.d/20-k8s-installer.conf <<EOF
[Service]
Environment="KUBELET_EXTRA_ARGS=--root-dir=$KUBELET_ROOT_DIR"
EOF
  systemctl daemon-reload
}
