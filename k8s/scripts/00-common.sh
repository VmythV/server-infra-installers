#!/bin/sh

LOG_FILE="${LOG_FILE:-/var/log/k8s-installer.log}"
STEP_LOG_FILE="${STEP_LOG_FILE:-/var/log/k8s-installer-steps.jsonl}"
STATE_DIR="${STATE_DIR:-/var/lib/k8s-installer}"
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
  tmp="${TMPDIR:-/tmp}/k8s-installer.$$.out"
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
  name=$1
  current=$2
  desc=$3
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

normalize_config() {
  if [ "$CN" = "1" ]; then
    REWRITE_IMAGES=true
    K8S_IMAGE_REPO="${IMAGE_MIRROR_PREFIX}/registry.k8s.io"
  elif [ "$REWRITE_IMAGES" = "true" ]; then
    K8S_IMAGE_REPO="${IMAGE_MIRROR_PREFIX}/registry.k8s.io"
  else
    K8S_IMAGE_REPO="registry.k8s.io"
  fi
  export REWRITE_IMAGES K8S_IMAGE_REPO
}

print_banner() {
  log_info "Kubernetes installer"
  log_info "K8S_VERSION=$K8S_VERSION CN=$CN REWRITE_IMAGES=$REWRITE_IMAGES"
}

prompt_config() {
  if ! is_unattended; then
    CN=$(prompt_value CN "$CN" "China mode, 1 enables China-accessible mirrors")
    POD_CIDR=$(prompt_value POD_CIDR "$POD_CIDR" "Pod CIDR")
    SERVICE_CIDR=$(prompt_value SERVICE_CIDR "$SERVICE_CIDR" "Service CIDR")
    K8S_DATA_ROOT=$(prompt_value K8S_DATA_ROOT "$K8S_DATA_ROOT" "Kubernetes data root")
    CONTAINERD_ROOT_DIR="${CONTAINERD_ROOT_DIR:-${K8S_DATA_ROOT}/containerd/root}"
    CONTAINERD_STATE_DIR="${CONTAINERD_STATE_DIR:-${K8S_DATA_ROOT}/containerd/state}"
    KUBELET_ROOT_DIR="${KUBELET_ROOT_DIR:-${K8S_DATA_ROOT}/kubelet}"
    KUBELET_POD_LOG_DIR="${KUBELET_POD_LOG_DIR:-${K8S_DATA_ROOT}/logs/pods}"
    ETCD_DATA_DIR="${ETCD_DATA_DIR:-${K8S_DATA_ROOT}/etcd}"
    K8S_MANIFEST_DIR="${K8S_MANIFEST_DIR:-${K8S_DATA_ROOT}/manifests}"
    K8S_RESOURCE_DIR="${K8S_RESOURCE_DIR:-${K8S_DATA_ROOT}/resources}"
    K8S_LOCAL_PV_ROOT="${K8S_LOCAL_PV_ROOT:-${K8S_DATA_ROOT}/local-pv}"
    K8S_PVC_ROOT="${K8S_PVC_ROOT:-${K8S_DATA_ROOT}/pvc}"
    K8S_DOWNLOAD_DIR="${K8S_DOWNLOAD_DIR:-${K8S_DATA_ROOT}/downloads}"
    K8S_BACKUP_DIR="${K8S_BACKUP_DIR:-${K8S_DATA_ROOT}/backups}"
    normalize_config
    confirm "Proceed with Kubernetes installation?" || die "Installation cancelled"
  fi
  export CN POD_CIDR SERVICE_CIDR K8S_DATA_ROOT CONTAINERD_ROOT_DIR CONTAINERD_STATE_DIR
  export KUBELET_ROOT_DIR KUBELET_POD_LOG_DIR ETCD_DATA_DIR K8S_MANIFEST_DIR K8S_RESOURCE_DIR
  export K8S_LOCAL_PV_ROOT K8S_PVC_ROOT K8S_DOWNLOAD_DIR K8S_BACKUP_DIR
}

image_ref() {
  img=$1
  if [ "$REWRITE_IMAGES" = "true" ]; then
    case "$img" in
      "$IMAGE_MIRROR_PREFIX"/*) printf '%s\n' "$img" ;;
      *) printf '%s/%s\n' "$IMAGE_MIRROR_PREFIX" "$img" ;;
    esac
  else
    printf '%s\n' "$img"
  fi
}

kubectl_cmd() {
  KUBECONFIG=/etc/kubernetes/admin.conf kubectl "$@"
}

wait_deploy() {
  ns=$1
  name=$2
  timeout=${3:-180s}
  run_cmd verify kubectl_cmd -n "$ns" rollout status "deployment/$name" "--timeout=$timeout"
}

write_state() {
  mkdir -p "$STATE_DIR"
  cat > "$STATE_DIR/state.env" <<EOF
K8S_VERSION="$K8S_VERSION"
ASSUME_YES="$ASSUME_YES"
NON_INTERACTIVE="$NON_INTERACTIVE"
CN="$CN"
IMAGE_MIRROR_PREFIX="$IMAGE_MIRROR_PREFIX"
REWRITE_IMAGES="$REWRITE_IMAGES"
POD_CIDR="$POD_CIDR"
SERVICE_CIDR="$SERVICE_CIDR"
K8S_DATA_ROOT="$K8S_DATA_ROOT"
CONTAINERD_ROOT_DIR="$CONTAINERD_ROOT_DIR"
CONTAINERD_STATE_DIR="$CONTAINERD_STATE_DIR"
KUBELET_ROOT_DIR="$KUBELET_ROOT_DIR"
KUBELET_POD_LOG_DIR="$KUBELET_POD_LOG_DIR"
ETCD_DATA_DIR="$ETCD_DATA_DIR"
K8S_LOCAL_PV_ROOT="$K8S_LOCAL_PV_ROOT"
K8S_PVC_ROOT="$K8S_PVC_ROOT"
EOF
}
