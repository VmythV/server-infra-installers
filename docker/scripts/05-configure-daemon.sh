#!/bin/sh

configure_docker_daemon() {
  mkdir -p "$DOCKER_CONFIG_DIR"
  if [ -f "$DOCKER_CONFIG_DIR/daemon.json" ]; then
    cp "$DOCKER_CONFIG_DIR/daemon.json" "$DOCKER_BACKUP_DIR/daemon.json.$(date +%Y%m%d%H%M%S).bak"
  fi
  mirrors=$(csv_to_json_array "$DOCKER_REGISTRY_MIRRORS")
  cat > "$DOCKER_CONFIG_DIR/daemon.json" <<EOF
{
  "data-root": "$DOCKER_DATA_ROOT",
  "exec-root": "$DOCKER_EXEC_ROOT",
  "log-driver": "$DOCKER_LOG_DRIVER",
  "log-opts": {
    "max-size": "$DOCKER_LOG_MAX_SIZE",
    "max-file": "$DOCKER_LOG_MAX_FILE"
  },
  "live-restore": $DOCKER_LIVE_RESTORE,
  "iptables": $DOCKER_IPTABLES,
  "registry-mirrors": $mirrors
}
EOF
  run_cmd "05-configure-daemon" systemctl daemon-reload
  run_cmd "05-configure-daemon" systemctl enable --now docker
  run_cmd "05-configure-daemon" systemctl restart docker
}
