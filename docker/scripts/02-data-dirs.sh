#!/bin/sh

init_data_dirs() {
  for d in "$DOCKER_DATA_ROOT" "$DOCKER_DOWNLOAD_DIR" "$DOCKER_BACKUP_DIR" "$DOCKER_CONFIG_DIR"; do
    mkdir -p "$d"
  done
  chmod 700 "$DOCKER_BACKUP_DIR"
  df -Pk "$DOCKER_DATA_ROOT" | awk 'NR==2 { if ($4 < 5242880) exit 1 }' || die "DOCKER_DATA_ROOT needs at least 5GiB free space."
  write_state
}
