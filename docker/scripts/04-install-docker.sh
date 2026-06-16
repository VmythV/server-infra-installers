#!/bin/sh

install_docker_packages() {
  case "$PKG_MANAGER" in
    apt)
      if [ -n "$DOCKER_VERSION" ]; then
        version=$DOCKER_VERSION
        run_cmd "04-install-docker" apt-get install -y \
          "docker-ce=$version" "docker-ce-cli=$version" containerd.io docker-buildx-plugin docker-compose-plugin
      else
        run_cmd "04-install-docker" apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      fi
      ;;
    dnf|yum)
      if [ -n "$DOCKER_VERSION" ]; then
        run_cmd "04-install-docker" "$PKG_MANAGER" install -y \
          "docker-ce-$DOCKER_VERSION" "docker-ce-cli-$DOCKER_VERSION" containerd.io docker-buildx-plugin docker-compose-plugin
      else
        run_cmd "04-install-docker" "$PKG_MANAGER" install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      fi
      ;;
  esac
}
