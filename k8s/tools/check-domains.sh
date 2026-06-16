#!/bin/sh
set -eu

mode=${CN:-0}
target=${1:-.}

if [ "$mode" = "1" ]; then
  failed=0
  tmp=/tmp/k8s-domain-check.$$
  : > "$tmp"

  find "$target/manifests" -type f \( -name '*.yaml' -o -name '*.yml' \) 2>/dev/null | while IFS= read -r file; do
    awk '
      /^[[:space:]]*image:[[:space:]]*/ {
        image=$0
        sub(/^[[:space:]]*image:[[:space:]]*/, "", image)
        gsub(/["'\'']/, "", image)
        if (image ~ /^(registry\.k8s\.io|docker\.io|quay\.io|ghcr\.io|gcr\.io|k8s\.gcr\.io)\//) {
          print FILENAME ":" FNR ":" image
        }
      }
    ' "$file"
  done >> "$tmp"

  if [ -s "$tmp" ]; then
    cat "$tmp" >&2
    failed=1
  fi
  rm -f "$tmp"

  if [ "$failed" -ne 0 ]; then
    echo "CN=1 image domain check failed." >&2
    exit 1
  fi
fi

echo "domain check passed"
