#!/bin/sh

configure_docker_repository() {
  case "$PKG_MANAGER" in
    apt) configure_docker_apt ;;
    dnf|yum) configure_docker_yum ;;
  esac
}

configure_docker_apt() {
  repo_base=$DOCKER_APT_REPO_BASE
  [ "$CN" = "1" ] && repo_base=$CN_DOCKER_APT_REPO_BASE

  case "$OS_ID" in
    ubuntu|debian) distro=$OS_ID ;;
    *) die "APT Docker install supports ubuntu/debian, got $OS_ID" ;;
  esac
  [ -n "$OS_CODENAME" ] || die "Cannot detect OS codename for apt repository."

  run_cmd "03-repository" apt-get update
  run_cmd "03-repository" apt-get install -y ca-certificates curl gnupg
  mkdir -p /etc/apt/keyrings
  rm -f /etc/apt/keyrings/docker.gpg
  curl -fsSL "$repo_base/$distro/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] $repo_base/$distro $OS_CODENAME stable" > /etc/apt/sources.list.d/docker-installer.list
  run_cmd "03-repository" apt-get update
}

configure_docker_yum() {
  repo=$DOCKER_YUM_REPO_BASE
  [ "$CN" = "1" ] && repo=$CN_DOCKER_YUM_REPO_BASE
  if [ "$PKG_MANAGER" = "dnf" ]; then
    run_cmd "03-repository" dnf install -y dnf-plugins-core
  else
    run_cmd "03-repository" yum install -y yum-utils
  fi
  run_cmd "03-repository" "$PKG_MANAGER" config-manager --add-repo "$repo"
}
