#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <comfyui-ref> <comfyui-sha>" >&2
  exit 64
fi

ref="$1"
sha="$2"

COMFYUI_REF="$ref" COMFYUI_SHA="$sha" python3 - <<'PY'
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request


repo = "comfyanonymous/ComfyUI"
api_base = os.environ.get("GITHUB_API_URL", "https://api.github.com").rstrip("/")
ref = os.environ["COMFYUI_REF"]
sha = os.environ["COMFYUI_SHA"]

headers = {
    "Accept": "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
}

token = os.environ.get("GITHUB_TOKEN")
if token:
    headers["Authorization"] = f"Bearer {token}"


def get_json(path: str, *, allow_404: bool = False):
    request = urllib.request.Request(f"{api_base}{path}", headers=headers)
    try:
        with urllib.request.urlopen(request) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        if allow_404 and error.code == 404:
            return None

        body = error.read().decode("utf-8", "replace")
        print(
            f"GitHub API request failed for {path}: HTTP {error.code}: {body}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
    except urllib.error.URLError as error:
        print(f"GitHub API request failed for {path}: {error.reason}", file=sys.stderr)
        raise SystemExit(1) from error


def release_tag_candidate(ref_name):
    if ref_name == "master":
        return None
    if ref_name.startswith("refs/tags/"):
        return ref_name[len("refs/tags/") :]
    if ref_name.startswith("refs/"):
        return None
    return ref_name


commit = get_json(f"/repos/{repo}/commits/{sha}")
try:
    commit_date = commit["commit"]["committer"]["date"]
except KeyError as error:
    print("GitHub commit response did not include commit.committer.date", file=sys.stderr)
    raise SystemExit(1) from error

release_published_at = ""
tag = release_tag_candidate(ref)
if tag:
    encoded_tag = urllib.parse.quote(tag, safe="")
    release = get_json(f"/repos/{repo}/releases/tags/{encoded_tag}", allow_404=True)
    if release is not None:
        try:
            release_published_at = release["published_at"]
        except KeyError as error:
            print("GitHub release response did not include published_at", file=sys.stderr)
            raise SystemExit(1) from error

print(f"commit_date={commit_date}")
if release_published_at:
    print(f"release_published_at={release_published_at}")

print("bake_set<<EOF")
print(f"*.labels.comfyui.commit.date={commit_date}")
if release_published_at:
    print(f"*.labels.comfyui.release.published_at={release_published_at}")
print("EOF")
PY
