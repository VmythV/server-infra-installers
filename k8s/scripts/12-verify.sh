#!/bin/sh

verify_cluster() {
  run_cmd "12-verify" kubectl_cmd get nodes -o wide
  run_cmd "12-verify" kubectl_cmd get pods -A
  kubectl_cmd top nodes >/dev/null 2>&1 || log_warn "kubectl top nodes is not ready yet."
  kubectl_cmd get ingressclass >/dev/null 2>&1 || true
  kubectl_cmd get svc -n traefik >/dev/null 2>&1 || true
  systemctl list-timers | grep k8s-cert-renew >/dev/null 2>&1 || log_warn "k8s-cert-renew timer is not listed."
  print_summary
}

print_summary() {
  cat <<EOF
Kubernetes: v$K8S_VERSION
Mode: CN=$CN
Rewrite images: $REWRITE_IMAGES
Runtime: containerd
CNI: Calico
Ingress Controller: Traefik
Traefik HTTP NodePort: $TRAEFIK_HTTP_NODEPORT
Traefik HTTPS NodePort: $TRAEFIK_HTTPS_NODEPORT
Single-node scheduling: $ALLOW_SINGLE_NODE_SCHEDULING
Certificate auto-renew: $CERT_RENEW_ENABLE
Kubeconfig: /root/.kube/config
Data root: $K8S_DATA_ROOT
containerd root: $CONTAINERD_ROOT_DIR
kubelet root: $KUBELET_ROOT_DIR
etcd data: $ETCD_DATA_DIR
Pod logs: $KUBELET_POD_LOG_DIR
Local PV root: $K8S_LOCAL_PV_ROOT
PVC root: $K8S_PVC_ROOT
Log: $LOG_FILE
Step log: $STEP_LOG_FILE
EOF
}
