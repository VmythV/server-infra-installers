#!/bin/sh

install_containerd() {
  if ! command -v containerd >/dev/null 2>&1; then
    case "$PKG_MANAGER" in
      apt)
        run_cmd "04-containerd" apt-get update
        run_cmd "04-containerd" apt-get install -y ca-certificates curl gnupg apt-transport-https containerd
        ;;
      dnf|yum)
        run_cmd "04-containerd" "$PKG_MANAGER" install -y yum-utils device-mapper-persistent-data lvm2 containerd
        ;;
    esac
  else
    log_info "containerd already installed."
  fi

  mkdir -p /etc/containerd
  if command -v containerd >/dev/null 2>&1; then
    containerd config default > /etc/containerd/config.toml.tmp || true
  fi
  if [ -s /etc/containerd/config.toml.tmp ]; then
    mv /etc/containerd/config.toml.tmp /etc/containerd/config.toml
  else
    cat > /etc/containerd/config.toml <<EOF
version = 2
[plugins."io.containerd.grpc.v1.cri"]
  sandbox_image = "$(image_ref "registry.k8s.io/pause:3.10")"
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  SystemdCgroup = true
EOF
  fi

  # Keep edits simple and explicit.
  sed -i.bak \
    -e "s#^root = .*#root = \"$CONTAINERD_ROOT_DIR\"#" \
    -e "s#^state = .*#state = \"$CONTAINERD_STATE_DIR\"#" \
    -e "s#SystemdCgroup = false#SystemdCgroup = true#g" \
    -e "s#sandbox_image = \".*\"#sandbox_image = \"$(image_ref "registry.k8s.io/pause:3.10")\"#" \
    /etc/containerd/config.toml || true

  systemctl daemon-reload
  run_cmd "04-containerd" systemctl enable --now containerd
  run_cmd "04-containerd" systemctl restart containerd
}
