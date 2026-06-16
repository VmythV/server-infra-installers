#!/bin/sh
set -eu

target=${1:-manifests}
if [ ! -e "$target" ]; then
  echo "target not found: $target" >&2
  exit 1
fi

find "$target" -type f \( -name '*.yaml' -o -name '*.yml' \) -print | while IFS= read -r file; do
  awk '
    /^[[:space:]]*image:[[:space:]]*/ {
      sub(/^[[:space:]]*image:[[:space:]]*/, "", $0)
      gsub(/["'\'']/, "", $0)
      print FILENAME ":" $0
    }
  ' "$file"
done
