#!/usr/bin/env bash
set -euo pipefail

api_base="${GITHUB_API_URL:-https://api.github.com}"
url="${api_base}/repos/comfyanonymous/ComfyUI/releases/latest"

headers=(
  -H "Accept: application/vnd.github+json"
  -H "X-GitHub-Api-Version: 2022-11-28"
)

if [ -n "${GITHUB_TOKEN:-}" ]; then
  headers+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

json=$(curl -fsSL "${headers[@]}" "$url")
tag=$(
  printf '%s\n' "$json" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1
)

if [ -z "$tag" ]; then
  echo "Unable to resolve latest ComfyUI release tag" >&2
  exit 1
fi

printf '%s\n' "$tag"
