#!/bin/sh

install_calico() {
  if kubectl_cmd get pods -n calico-system >/dev/null 2>&1 || kubectl_cmd get ds -n kube-system calico-node >/dev/null 2>&1; then
    log_info "Calico appears installed; skip."
    return 0
  fi
  manifest=$(resolve_manifest calico "$CALICO_MANIFEST_URL")
  run_cmd "07-calico" kubectl_cmd apply -f "$manifest"
  wait_for_pods kube-system 300
}

resolve_manifest() {
  name=$1
  url=$2
  local_file="$K8S_MANIFEST_DIR/$name.yaml"
  repo_file="$SCRIPT_DIR/manifests/$name.yaml"
  if [ "$CN" = "1" ] || [ "$REWRITE_IMAGES" = "true" ]; then
    [ -s "$local_file" ] && { printf '%s\n' "$local_file"; return 0; }
    [ -s "$repo_file" ] && { printf '%s\n' "$repo_file"; return 0; }
    die "$name manifest is required locally when CN=1 or REWRITE_IMAGES=true. Run k8s/tools/sync-manifests.sh and rewrite-images.sh first."
  fi
  [ -s "$local_file" ] && { printf '%s\n' "$local_file"; return 0; }
  [ -s "$repo_file" ] && { printf '%s\n' "$repo_file"; return 0; }
  printf '%s\n' "$url"
}

wait_for_pods() {
  ns=$1
  timeout=${2:-180}
  end=$(( $(date +%s) + timeout ))
  while [ "$(date +%s)" -lt "$end" ]; do
    if kubectl_cmd get pods -n "$ns" >/dev/null 2>&1; then
      not_ready=$(kubectl_cmd get pods -n "$ns" --no-headers 2>/dev/null | awk '$3 !~ /Running|Completed/ {c++} END {print c+0}')
      [ "$not_ready" -eq 0 ] && return 0
    fi
    sleep 5
  done
  kubectl_cmd get pods -A || true
  die "Pods in namespace $ns did not become ready."
}
