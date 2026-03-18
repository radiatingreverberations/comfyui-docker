#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <comfyui-ref>" >&2
  exit 64
fi

ref="$1"
repo="https://github.com/comfyanonymous/ComfyUI.git"

patterns=()
case "$ref" in
  refs/tags/*)
    patterns+=("${ref}^{}" "$ref")
    ;;
  refs/heads/*|refs/*)
    patterns+=("$ref")
    ;;
  *)
    patterns+=("refs/tags/${ref}^{}" "refs/tags/${ref}" "refs/heads/${ref}")
    ;;
esac

for pattern in "${patterns[@]}"; do
  sha=$(git ls-remote --exit-code "$repo" "$pattern" | awk 'NR == 1 { print $1 }') || true
  if [ -n "$sha" ]; then
    printf '%s\n' "$sha"
    exit 0
  fi
done

echo "Unable to resolve ComfyUI ref '$ref' to a single SHA" >&2
exit 1
