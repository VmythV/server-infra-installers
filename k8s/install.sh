#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if [ ! -f "$SCRIPT_DIR/config.env" ] || [ ! -f "$SCRIPT_DIR/scripts/00-common.sh" ]; then
  K8S_INSTALLER_VERSION="${K8S_INSTALLER_VERSION:-v1.0.0}"
  RELEASE_BASE_URL="${RELEASE_BASE_URL:-https://k8s-install.example.cn/releases}"
  arch=$(uname -m)
  case "$arch" in
    x86_64) arch=amd64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) echo "Unsupported architecture: $arch" >&2; exit 1 ;;
  esac
  suffix=""
  [ "${CN:-0}" = "1" ] && suffix="-cn"
  tarball="k8s-installer-${K8S_INSTALLER_VERSION}-linux-${arch}${suffix}.tar.gz"
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
  if [ -x "$tmpdir/k8s/install.sh" ]; then
    exec "$tmpdir/k8s/install.sh" "$@"
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
. "$SCRIPT_DIR/scripts/02-os-init.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/scripts/03-data-dirs.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/scripts/04-containerd.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/scripts/05-kubernetes-packages.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/scripts/06-kubeadm-init.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/scripts/07-calico.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/scripts/08-metrics-server.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/scripts/09-traefik.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/scripts/10-single-node.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/scripts/11-cert-renew.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/scripts/12-verify.sh"

main() {
  init_logging
  normalize_config
  print_banner
  prompt_config

  run_step "01-detect" detect_environment

  if cluster_is_ready; then
    log_info "Existing Kubernetes cluster is healthy; skip installation."
    verify_cluster || true
    exit 0
  fi

  run_step "02-os-init" init_os
  run_step "03-data-dirs" init_data_dirs
  run_step "04-containerd" install_containerd
  run_step "05-kubernetes-packages" install_kubernetes_packages
  run_step "06-kubeadm-init" init_kubeadm_cluster
  run_step "07-calico" install_calico

  if [ "$INSTALL_METRICS_SERVER" = "true" ]; then
    run_step "08-metrics-server" install_metrics_server
  else
    mark_step "08-metrics-server" "SKIPPED"
  fi

  if [ "$INSTALL_INGRESS" = "true" ]; then
    run_step "09-traefik" install_traefik
  else
    mark_step "09-traefik" "SKIPPED"
  fi

  if [ "$ALLOW_SINGLE_NODE_SCHEDULING" = "true" ]; then
    run_step "10-single-node" enable_single_node_scheduling
  else
    mark_step "10-single-node" "SKIPPED"
  fi

  if [ "$CERT_RENEW_ENABLE" = "true" ]; then
    run_step "11-cert-renew" install_cert_renew
  else
    mark_step "11-cert-renew" "SKIPPED"
  fi

  run_step "12-verify" verify_cluster
}

main "$@"
