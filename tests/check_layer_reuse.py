"""Build two source revisions and verify that only the source layer changes.

Requires Docker Buildx and registry access. Builds local images without pushing.
Both commits must have identical requirements, but different application files.
Test images are removed afterwards unless --keep-images is specified.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import urllib.request
import uuid


ROOT = Path(__file__).resolve().parents[1]
TARGETS = ("comfyui-base", "comfyui-extensions", "comfyui-ssh")


def commit_sha(value: str) -> str:
    if not re.fullmatch(r"[0-9a-f]{40}", value):
        raise argparse.ArgumentTypeError("use an immutable, full ComfyUI commit SHA")
    return value


def requirements(ref: str, name: str) -> bytes:
    url = f"https://raw.githubusercontent.com/comfyanonymous/ComfyUI/{ref}/{name}"
    with urllib.request.urlopen(url, timeout=60) as response:
        return response.read()


def image_tag(target: str, variant: str) -> str:
    return f"local/{target}-layer-check:{variant}"


def build(ref: str, variant: str, flavor: str) -> dict[str, list[str]]:
    command = [
        "docker", "buildx", "bake", "--progress=plain", "--load",
        "--set", f"*.args.COMFYUI_VERSION={ref}",
        "--set", f"*.args.REFRESH_COMFYUI={ref}",
        "--set", f"*.labels.comfyui.sha={ref}",
    ]
    for target in TARGETS:
        command.extend(["--set", f"{target}.tags={image_tag(target, variant)}"])

    env = dict(os.environ, BASE_FLAVOR=flavor, IMAGE_LABEL="master")
    print(f"Building {variant}: {ref} ({flavor})", flush=True)
    with tempfile.TemporaryFile(mode="w+", encoding="utf-8") as log:
        result = subprocess.run(command, cwd=ROOT, env=env, stdout=log, stderr=log)
        if result.returncode:
            log.seek(0)
            print("".join(log.readlines()[-100:]))
            raise RuntimeError(f"{variant} build failed: {result.returncode}")

    images = json.loads(subprocess.check_output(
        ["docker", "image", "inspect", *[image_tag(t, variant) for t in TARGETS]],
        text=True,
    ))
    return {target: image["RootFS"]["Layers"] for target, image in zip(TARGETS, images)}


def cleanup(variants: list[str]) -> None:
    expected = {image_tag(target, variant) for target in TARGETS for variant in variants}
    present = set(subprocess.check_output(
        ["docker", "image", "ls", "--format", "{{.Repository}}:{{.Tag}}"], text=True,
    ).splitlines())
    images = sorted(expected & present)
    if images:
        subprocess.run(["docker", "image", "rm", *images], check=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("before", type=commit_sha)
    parser.add_argument("after", type=commit_sha)
    parser.add_argument("--flavor", choices=("cpu", "amd", "nvidia"), default="cpu")
    parser.add_argument("--keep-images", action="store_true", help="retain local test images for debugging")
    args = parser.parse_args()

    for name in ("requirements.txt", "manager_requirements.txt"):
        if requirements(args.before, name) != requirements(args.after, name):
            parser.error(f"{name} differs; choose two source-only revisions")

    run_id = uuid.uuid4().hex[:12]
    variants = [f"before-{run_id}", f"after-{run_id}"]
    try:
        before = build(args.before, variants[0], args.flavor)
        after = build(args.after, variants[1], args.flavor)
        for target in TARGETS:
            old, new = before[target], after[target]
            if len(old) != len(new) or len(new) < 3:
                raise AssertionError(f"{target}: unexpected layer count")
            changed = [index for index, pair in enumerate(zip(old, new)) if pair[0] != pair[1]]
            # The source COPY must be the only layer invalidated by an upstream update.
            if changed != [len(new) - 1]:
                raise AssertionError(f"{target}: expected only source layer to change, got {changed}")
            print(f"PASS {target}: only source changed; {len(new) - 1} layers reused")
    finally:
        if not args.keep_images:
            cleanup(variants)


if __name__ == "__main__":
    main()
