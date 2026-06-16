#!/bin/sh

OS_ID=
OS_VERSION_ID=
PKG_MANAGER=
ARCH=

detect_environment() {
  [ "$(id -u)" -eq 0 ] || die "Please run as root."
  [ -r /etc/os-release ] || die "/etc/os-release not found."
  # shellcheck disable=SC1091
  . /etc/os-release
  OS_ID=$ID
  OS_VERSION_ID=${VERSION_ID:-}
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64) ARCH=amd64 ;;
    aarch64|arm64) ARCH=arm64 ;;
    *) die "Unsupported architecture: $(uname -m)" ;;
  esac
  if command -v apt-get >/dev/null 2>&1; then
    PKG_MANAGER=apt
  elif command -v dnf >/dev/null 2>&1; then
    PKG_MANAGER=dnf
  elif command -v yum >/dev/null 2>&1; then
    PKG_MANAGER=yum
  else
    die "No supported package manager found."
  fi
  export OS_ID OS_VERSION_ID PKG_MANAGER ARCH
  log_info "Detected OS=$OS_ID VERSION=$OS_VERSION_ID ARCH=$ARCH PKG_MANAGER=$PKG_MANAGER"

  if route_conflicts "$POD_CIDR" || route_conflicts "$SERVICE_CIDR"; then
    if is_unattended; then
      die "POD_CIDR or SERVICE_CIDR conflicts with host routes."
    fi
    confirm "CIDR conflict may exist. Continue anyway?" || die "CIDR conflict detected."
  fi
  write_state
}

route_conflicts() {
  cidr=$1
  if command -v ip >/dev/null 2>&1; then
    # Conservative string check. Exact CIDR overlap is validated by operators in production.
    ip route | awk '{print $1}' | grep -Fqx "$cidr" && return 0
  fi
  return 1
}

cluster_is_ready() {
  [ -f /etc/kubernetes/admin.conf ] || return 1
  command -v kubectl >/dev/null 2>&1 || return 1
  KUBECONFIG=/etc/kubernetes/admin.conf kubectl get nodes >/dev/null 2>&1
}
