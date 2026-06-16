#!/bin/sh

init_data_dirs() {
  for d in \
    "$K8S_DATA_ROOT" \
    "$CONTAINERD_ROOT_DIR" \
    "$CONTAINERD_STATE_DIR" \
    "$KUBELET_ROOT_DIR" \
    "$KUBELET_POD_LOG_DIR" \
    "$ETCD_DATA_DIR" \
    "$K8S_MANIFEST_DIR" \
    "$K8S_RESOURCE_DIR" \
    "$K8S_LOCAL_PV_ROOT" \
    "$K8S_PVC_ROOT" \
    "$K8S_DOWNLOAD_DIR" \
    "$K8S_BACKUP_DIR" \
    "$K8S_DATA_ROOT/logs/installer"; do
    mkdir -p "$d"
  done
  chmod 700 "$K8S_BACKUP_DIR"
  df -Pk "$K8S_DATA_ROOT" | awk 'NR==2 { if ($4 < 5242880) exit 1 }' || die "K8S_DATA_ROOT needs at least 5GiB free space."
  write_state
}
