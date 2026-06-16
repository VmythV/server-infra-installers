#!/bin/sh

LOG_FILE="${LOG_FILE:-/var/log/docker-installer.log}"
STEP_LOG_FILE="${STEP_LOG_FILE:-/var/log/docker-installer-steps.jsonl}"
STATE_DIR="${STATE_DIR:-/var/lib/docker-installer}"
STEP_STATE_DIR="${STEP_STATE_DIR:-${STATE_DIR}/steps}"

init_logging() {
  mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$STEP_LOG_FILE")" "$STEP_STATE_DIR"
  touch "$LOG_FILE" "$STEP_LOG_FILE"
}

now_iso() {
  date +"%Y-%m-%dT%H:%M:%S%z"
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

log_line() {
  level=$1
  shift
  msg=$*
  printf '%s [%s] %s\n' "$(now_iso)" "$level" "$msg" | tee -a "$LOG_FILE" >&2
}

log_info() { log_line INFO "$@"; }
log_warn() { log_line WARN "$@"; }
log_error() { log_line ERROR "$@"; }

step_event() {
  step=$1
  status=$2
  message=${3:-}
  printf '{"time":"%s","step":"%s","status":"%s","message":"%s"}\n' \
    "$(now_iso)" "$(json_escape "$step")" "$(json_escape "$status")" "$(json_escape "$message")" >> "$STEP_LOG_FILE"
}

mark_step() {
  step=$1
  status=$2
  mkdir -p "$STEP_STATE_DIR"
  printf '%s\n' "$status" > "$STEP_STATE_DIR/$step.status"
  step_event "$step" "$status" ""
}

die() {
  log_error "$*"
  exit 1
}

run_cmd() {
  step=$1
  shift
  log_info "[$step] $*"
  tmp="${TMPDIR:-/tmp}/docker-installer.$$.out"
  if "$@" >"$tmp" 2>&1; then
    sed 's/^/  /' "$tmp" >> "$LOG_FILE"
    rm -f "$tmp"
    return 0
  fi
  code=$?
  sed 's/^/  /' "$tmp" >> "$LOG_FILE"
  tail -30 "$tmp" >&2 || true
  rm -f "$tmp"
  printf '{"time":"%s","step":"%s","status":"FAILED","exit_code":%s,"command":"%s","log":"%s"}\n' \
    "$(now_iso)" "$(json_escape "$step")" "$code" "$(json_escape "$*")" "$(json_escape "$LOG_FILE")" >> "$STEP_LOG_FILE"
  return "$code"
}

run_step() {
  step=$1
  func=$2
  mark_step "$step" RUNNING
  log_info "Start step $step"
  start=$(date +%s)
  if "$func"; then
    end=$(date +%s)
    mark_step "$step" SUCCESS
    log_info "Step $step succeeded in $((end - start))s"
    return 0
  fi
  code=$?
  mark_step "$step" FAILED
  log_error "Step $step failed with exit code $code"
  exit "$code"
}

is_yes() {
  case "${1:-}" in
    1|y|Y|yes|YES|true|TRUE) return 0 ;;
    *) return 1 ;;
  esac
}

is_unattended() {
  is_yes "$ASSUME_YES" || is_yes "$NON_INTERACTIVE"
}

confirm() {
  prompt=$1
  if is_unattended; then
    return 0
  fi
  printf '%s [y/N]: ' "$prompt" >&2
  read ans || ans=
  is_yes "$ans"
}

prompt_value() {
  current=$1
  desc=$2
  if is_unattended; then
    printf '%s' "$current"
    return 0
  fi
  printf '%s [%s]: ' "$desc" "$current" >&2
  read ans || ans=
  if [ -n "$ans" ]; then
    printf '%s' "$ans"
  else
    printf '%s' "$current"
  fi
}

csv_to_json_array() {
  value=$1
  [ -n "$value" ] || { printf '[]'; return 0; }
  printf '%s' "$value" | awk -F, '
    BEGIN { printf "[" }
    {
      for (i=1;i<=NF;i++) {
        gsub(/^[ \t]+|[ \t]+$/, "", $i)
        if ($i != "") {
          if (n++) printf ","
          gsub(/"/, "\\\"", $i)
          printf "\"%s\"", $i
        }
      }
    }
    END { printf "]" }
  '
}

print_banner() {
  log_info "Docker installer"
  log_info "CN=$CN DOCKER_DATA_ROOT=$DOCKER_DATA_ROOT"
}

prompt_config() {
  if ! is_unattended; then
    CN=$(prompt_value "$CN" "China mode, 1 enables China-accessible Docker package repository")
    DOCKER_DATA_ROOT=$(prompt_value "$DOCKER_DATA_ROOT" "Docker data root")
    if [ "$CN" = "1" ] && [ -z "$DOCKER_REGISTRY_MIRRORS" ] && [ -n "$CN_DOCKER_REGISTRY_MIRRORS" ]; then
      DOCKER_REGISTRY_MIRRORS=$CN_DOCKER_REGISTRY_MIRRORS
    fi
    DOCKER_REGISTRY_MIRRORS=$(prompt_value "$DOCKER_REGISTRY_MIRRORS" "Docker registry mirrors, comma separated; empty disables")
    confirm "Proceed with Docker installation?" || die "Installation cancelled"
  fi
  if [ "$CN" = "1" ] && [ -z "$DOCKER_REGISTRY_MIRRORS" ] && [ -n "$CN_DOCKER_REGISTRY_MIRRORS" ]; then
    DOCKER_REGISTRY_MIRRORS=$CN_DOCKER_REGISTRY_MIRRORS
  fi
  export CN DOCKER_DATA_ROOT DOCKER_REGISTRY_MIRRORS
}

write_state() {
  mkdir -p "$STATE_DIR"
  cat > "$STATE_DIR/state.env" <<EOF
ASSUME_YES="$ASSUME_YES"
NON_INTERACTIVE="$NON_INTERACTIVE"
CN="$CN"
DOCKER_VERSION="$DOCKER_VERSION"
DOCKER_DATA_ROOT="$DOCKER_DATA_ROOT"
DOCKER_EXEC_ROOT="$DOCKER_EXEC_ROOT"
DOCKER_REGISTRY_MIRRORS="$DOCKER_REGISTRY_MIRRORS"
EOF
}
