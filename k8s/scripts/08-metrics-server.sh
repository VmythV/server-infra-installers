#!/bin/sh

install_metrics_server() {
  if kubectl_cmd get deployment -n kube-system metrics-server >/dev/null 2>&1; then
    log_info "metrics-server already installed; skip."
    return 0
  fi
  manifest=$(resolve_manifest metrics-server "$METRICS_SERVER_MANIFEST_URL")
  tmp="$K8S_RESOURCE_DIR/metrics-server.yaml"
  mkdir -p "$K8S_RESOURCE_DIR"
  cp "$manifest" "$tmp" 2>/dev/null || curl -fsSL "$manifest" -o "$tmp"
  if ! grep -q -- "--kubelet-insecure-tls" "$tmp"; then
    # Best effort patch for common kubeadm single-node setups.
    sed -i.bak '/--metric-resolution/a\        - --kubelet-insecure-tls\n        - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname' "$tmp" || true
  fi
  run_cmd "08-metrics-server" kubectl_cmd apply -f "$tmp"
  run_cmd "08-metrics-server" kubectl_cmd -n kube-system rollout status deployment/metrics-server --timeout=180s
}
