#!/bin/sh

init_os() {
  if swapon --show | grep -q .; then
    run_cmd "02-os-init" swapoff -a
  fi
  if [ -f /etc/fstab ]; then
    cp /etc/fstab "/etc/fstab.k8s-installer.$(date +%Y%m%d%H%M%S).bak"
    sed -i.bak '/[[:space:]]swap[[:space:]]/ s/^/# k8s-installer disabled swap /' /etc/fstab || true
  fi

  cat > /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF
  run_cmd "02-os-init" modprobe overlay
  run_cmd "02-os-init" modprobe br_netfilter

  cat > /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
  run_cmd "02-os-init" sysctl --system

  if command -v getenforce >/dev/null 2>&1; then
    mode=$(getenforce || true)
    if [ "$mode" = "Enforcing" ]; then
      run_cmd "02-os-init" setenforce 0
      if [ -f /etc/selinux/config ]; then
        sed -i.bak 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config || true
      fi
    fi
  fi

  log_warn "If firewall is enabled, allow TCP 6443,2379-2380,10250,10257,10259,30080,30443."
}
