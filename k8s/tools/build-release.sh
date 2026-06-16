#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
VERSION=${K8S_INSTALLER_VERSION:-v1.0.0}
OUT_DIR=${OUT_DIR:-"$ROOT_DIR/releases/k8s"}

mkdir -p "$OUT_DIR"

make_one() {
  arch=$1
  suffix=$2
  name="k8s-installer-${VERSION}-linux-${arch}${suffix}.tar.gz"
  tmp=$(mktemp -d)
  mkdir -p "$tmp/k8s"
  (cd "$ROOT_DIR" && tar -cf - k8s README.md standards templates) | (cd "$tmp" && tar -xf -)
  (cd "$tmp" && tar -czf "$OUT_DIR/$name" k8s README.md standards templates)
  rm -rf "$tmp"
}

make_one amd64 ""
make_one arm64 ""
make_one amd64 "-cn"
make_one arm64 "-cn"

(cd "$OUT_DIR" && sha256sum k8s-installer-"$VERSION"-linux-*.tar.gz > SHA256SUMS)
echo "Release files written to $OUT_DIR"
