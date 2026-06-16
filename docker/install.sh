#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if [ ! -f "$SCRIPT_DIR/config.env" ] || [ ! -f "$SCRIPT_DIR/scripts/00-common.sh" ]; then
  DOCKER_INSTALLER_VERSION="${DOCKER_INSTALLER_VERSION:-v1.0.0}"
  RELEASE_BASE_URL="${RELEASE_BASE_URL:-https://docker-install.example.cn/releases}"
  arch=$(uname -m)
  case "$arch" in
    x86_64) arch=amd64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) echo "Unsupported architecture: $arch" >&2; exit 1 ;;
  esac
  suffix=""
  [ "${CN:-0}" = "1" ] && suffix="-cn"
  tarball="docker-installer-${DOCKER_INSTALLER_VERSION}-linux-${arch}${suffix}.tar.gz"
  tmpdir=$(mktemp -d)
  cleanup_bootstrap() { rm -rf "$tmpdir"; }
  trap cleanup_bootstrap EXIT INT TERM
  echo "Downloading $RELEASE_BASE_URL/$tarball" >&2
  curl -fsSL "$RELEASE_BASE_URL/$tarball" -o "$tmpdir/$tarball"
  if curl -fsSL "$RELEASE_BASE_URL/SHA256SUMS" -o "$tmpdir/SHA256SUMS"; then
    (cd "$tmpdir" && grep "  $tarball\$" SHA256SUMS | sha256sum -c -)
  else
    echo "WARN: SHA256SUMS not available; skip checksum verification." >&2
  fi
  tar -xzf "$tmpdir/$tarball" -C "$tmpdir"
  if [ -x "$tmpdir/docker/install.sh" ]; then
    exec "$tmpdir/docker/install.sh" "$@"
  fi
  if [ -x "$tmpdir/install.sh" ]; then
    exec "$tmpdir/install.sh" "$@"
  fi
  echo "Installer entry not found in $tarball" >&2
  exit 1
fi

# shellcheck disable=SC1091
. "$SCRIPT_DIR/config.env"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/scripts/00-common.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/scripts/01-detect.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/scripts/02-data-dirs.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/scripts/03-repository.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/scripts/04-install-docker.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/scripts/05-configure-daemon.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/scripts/06-verify.sh"

main() {
  init_logging
  print_banner
  prompt_config

  run_step "01-detect" detect_environment

  if docker_is_ready; then
    log_info "Docker is already installed and healthy; skip installation."
    verify_docker || true
    exit 0
  fi

  run_step "02-data-dirs" init_data_dirs
  run_step "03-repository" configure_docker_repository
  run_step "04-install-docker" install_docker_packages
  run_step "05-configure-daemon" configure_docker_daemon
  run_step "06-verify" verify_docker
}

main "$@"
