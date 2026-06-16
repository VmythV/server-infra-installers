#!/bin/sh

OS_ID=
OS_VERSION_ID=
OS_CODENAME=
PKG_MANAGER=
ARCH=

detect_environment() {
  [ "$(id -u)" -eq 0 ] || die "Please run as root."
  [ -r /etc/os-release ] || die "/etc/os-release not found."
  # shellcheck disable=SC1091
  . /etc/os-release
  OS_ID=$ID
  OS_VERSION_ID=${VERSION_ID:-}
  OS_CODENAME=${VERSION_CODENAME:-}
  [ -n "$OS_CODENAME" ] || OS_CODENAME=$(awk -F= '/VERSION_CODENAME/ {print $2}' /etc/os-release 2>/dev/null || true)
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
  export OS_ID OS_VERSION_ID OS_CODENAME PKG_MANAGER ARCH
  log_info "Detected OS=$OS_ID VERSION=$OS_VERSION_ID CODENAME=$OS_CODENAME ARCH=$ARCH PKG_MANAGER=$PKG_MANAGER"
  write_state
}

docker_is_ready() {
  command -v docker >/dev/null 2>&1 || return 1
  docker info >/dev/null 2>&1
}
