#!/bin/sh

enable_single_node_scheduling() {
  kubectl_cmd taint nodes --all node-role.kubernetes.io/control-plane- >> "$LOG_FILE" 2>&1 || true
  kubectl_cmd taint nodes --all node-role.kubernetes.io/master- >/dev/null 2>&1 || true
  log_info "Single-node scheduling taints removed when present."
}
