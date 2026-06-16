#!/bin/sh
set -eu

target=${1:-manifests}
prefix=${IMAGE_MIRROR_PREFIX:-swr.cn-north-4.myhuaweicloud.com/ddn-k8s}

if [ ! -e "$target" ]; then
  echo "target not found: $target" >&2
  exit 1
fi

find "$target" -type f \( -name '*.yaml' -o -name '*.yml' \) -print | while IFS= read -r file; do
  tmp="${file}.tmp.$$"
  awk -v prefix="$prefix" '
    /^[[:space:]]*image:[[:space:]]*/ {
      indent=$0
      sub(/image:.*/, "", indent)
      image=$0
      sub(/^[[:space:]]*image:[[:space:]]*/, "", image)
      gsub(/["'\'']/, "", image)
      if (image !~ "^" prefix "/") {
        print indent "image: " prefix "/" image
        next
      }
    }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
done
