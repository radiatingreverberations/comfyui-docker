#!/usr/bin/env python3
# download_models.py

import os
import json
import shutil
import argparse
from urllib.parse import urlparse
from huggingface_hub import hf_hub_download
import requests

def parse_hf_url(url):
    """
    Parse Hugging Face URLs of the form:
    https://huggingface.co/{repo_id}/resolve/{revision}/{path}
    Returns (repo_id, revision, file_path)
    """
    parsed = urlparse(url)
    parts = parsed.path.strip("/").split("/")
    # Expect: [owner, repo, "resolve", revision, ...path parts]
    if len(parts) < 5 or parts[2] != "resolve":
        raise ValueError("Not a HF resolve URL")
    repo_id = f"{parts[0]}/{parts[1]}"
    revision = parts[3]
    file_path = "/".join(parts[4:])
    return repo_id, revision, file_path

def download_models_from_json(json_file, output_dir="models", dry_run=False):
    os.makedirs(output_dir, exist_ok=True)

    # place HF cache inside the output directory
    hf_cache_dir = os.path.join(output_dir, "hf-cache")
    os.makedirs(hf_cache_dir, exist_ok=True)

    with open(json_file, "r", encoding="utf-8") as f:
        data = json.load(f)

    for node in data.get("nodes", []):
        models = node.get("properties", {}).get("models", [])
        for m in models:
            url       = m.get("url")
            directory = m.get("directory", "")
            name      = m.get("name")

            target_dir = os.path.join(output_dir, directory)
            os.makedirs(target_dir, exist_ok=True)
            dest_path = os.path.join(target_dir, name)

            # Remove existing file/link if it exists
            if os.path.lexists(dest_path):
                if os.path.islink(dest_path):
                    print(f"🗑️  Removing existing symlink: {dest_path}")
                    os.remove(dest_path)
                else:
                    print(f"⚠️  [skip] Already exists (regular file): {dest_path}")
                    continue

            # Dry-run: only report what would happen
            if dry_run:
                try:
                    parse_hf_url(url)
                    print(f"✔️  [dry-run] HF download: {name} → {dest_path}")
                except Exception:
                    print(f"✔️  [dry-run] HTTP download: {name} from {url} → {dest_path}")
                continue

            # Try HF API download
            try:
                repo_id, revision, file_path = parse_hf_url(url)
                cached = hf_hub_download(
                    repo_id=repo_id,
                    filename=file_path,
                    revision=revision,
                    cache_dir=hf_cache_dir
                )
                # Convert to absolute paths for linking
                cached_abs = os.path.abspath(cached)
                dest_path_abs = os.path.abspath(dest_path)

                # try symlink first, then copy as fallback
                try:
                    os.symlink(cached_abs, dest_path_abs)
                    print(f"🔗  HF symlink: {name} → {dest_path}")
                except OSError:
                    shutil.copy(cached_abs, dest_path_abs)
                    print(f"✔️  HF download (copied): {name} → {dest_path}")            # Fallback to plain HTTP
            except Exception:
                print(f"⏳  HTTP download: {name} from {url}")
                resp = requests.get(url, stream=True)
                resp.raise_for_status()
                with open(dest_path, "wb") as out:
                    for chunk in resp.iter_content(chunk_size=8192):
                        out.write(chunk)
                print(f"✔️  HTTP download done: {dest_path}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Download models listed in a JSON file."
    )
    parser.add_argument(
        "json_file", help="Path to the JSON file containing model URLs."
    )
    parser.add_argument(
        "-o", "--output-dir",
        default="models",
        help="Base directory where files will be saved."
    )
    parser.add_argument(
        "-n", "--dry-run",
        action="store_true",
        help="Show which files would be downloaded and where, without downloading."
    )
    args = parser.parse_args()

    download_models_from_json(args.json_file, args.output_dir, args.dry_run)
