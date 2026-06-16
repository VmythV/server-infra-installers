#!/bin/sh

verify_docker() {
  run_cmd "06-verify" docker version
  run_cmd "06-verify" docker info
  print_summary
}

print_summary() {
  cat <<EOF
Docker: $(docker --version 2>/dev/null || printf unknown)
Mode: CN=$CN
Data root: $DOCKER_DATA_ROOT
Exec root: $DOCKER_EXEC_ROOT
Registry mirrors: ${DOCKER_REGISTRY_MIRRORS:-none}
Log: $LOG_FILE
Step log: $STEP_LOG_FILE
EOF
}
