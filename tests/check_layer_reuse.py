"""Verify layer reuse for source-only updates or small requirements changes.

Requires Docker Buildx and registry access. Builds local images without pushing.
By default both commits must have identical requirements. --requirements-change
checks that small dependency updates reuse the baseline and stay below 128 MiB.
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
BASELINE_TARGET = "cached-dependencies-check"
BUILD_TARGETS = (*TARGETS, BASELINE_TARGET)
MAX_REQUIREMENTS_LAYER_BYTES = 128 * 1024 * 1024

RUNTIME_CHECK = """
from importlib.metadata import version
from pathlib import Path
from packaging.requirements import Requirement

for filename in ("requirements.txt", "manager_requirements.txt"):
    if filename == "manager_requirements.txt" and not Path("entrypoint.extensions.sh").exists():
        continue
    for line in Path(filename).read_text().splitlines():
        line = line.partition("#")[0].strip()
        if not line:
            continue
        requirement = Requirement(line)
        if requirement.marker is not None and not requirement.marker.evaluate():
            continue
        installed = version(requirement.name)
        assert installed in requirement.specifier, (filename, line, installed)
print("PASS: installed packages satisfy the image's requirements")
"""


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
        "docker", "buildx", "bake", "-f", "docker-bake.hcl",
        "-f", "tests/cache-check.hcl", "--progress=plain", "--load",
        "--set", f"*.args.COMFYUI_VERSION={ref}",
        "--set", f"*.args.REFRESH_COMFYUI={ref}",
        "--set", f"*.labels.comfyui.sha={ref}",
    ]
    for target in BUILD_TARGETS:
        command.extend(["--set", f"{target}.tags={image_tag(target, variant)}"])
        # Concurrent publishers can replace equivalent cache entries mid-check.
        # Reuse this builder's own cache for a deterministic before/after comparison.
        command.extend(["--set", f"{target}.cache-from="])
    command.extend(BUILD_TARGETS)

    env = dict(os.environ, BASE_FLAVOR=flavor, IMAGE_LABEL="master")
    print(f"Building {variant}: {ref} ({flavor})", flush=True)
    with tempfile.TemporaryFile(mode="w+", encoding="utf-8") as log:
        result = subprocess.run(command, cwd=ROOT, env=env, stdout=log, stderr=log)
        if result.returncode:
            log.seek(0)
            print("".join(log.readlines()[-100:]))
            raise RuntimeError(f"{variant} build failed: {result.returncode}")

    images = json.loads(subprocess.check_output(
        ["docker", "image", "inspect", *[image_tag(t, variant) for t in BUILD_TARGETS]],
        text=True,
    ))
    return {target: image["RootFS"]["Layers"] for target, image in zip(BUILD_TARGETS, images)}


def check_requirements_layer(target: str, variant: str) -> int:
    history = subprocess.check_output(
        ["docker", "image", "history", "--no-trunc", "--human=false",
         "--format", "{{json .}}", image_tag(target, variant)],
        text=True,
    )
    layers = [json.loads(line) for line in history.splitlines()]
    sizes = [int(layer["Size"]) for layer in layers
             if "-r requirements.txt" in layer["CreatedBy"]]
    if len(sizes) != 1:
        raise AssertionError(f"{target}: expected one upstream requirements install layer")
    if sizes[0] > MAX_REQUIREMENTS_LAYER_BYTES:
        raise AssertionError(
            f"{target}: requirements update layer is {sizes[0] / 1024**2:.1f} MiB; "
            "unchanged UI assets must stay in the cached baseline"
        )
    return sizes[0]


def check_runtime(target: str, variant: str) -> None:
    tag = image_tag(target, variant)
    subprocess.run(
        ["docker", "run", "--rm", "--entrypoint", "/opt/venv/bin/python",
         tag, "-c", RUNTIME_CHECK], check=True,
    )
    subprocess.run(
        ["docker", "run", "--rm", "--entrypoint", "/usr/local/bin/uv",
         tag, "pip", "check", "--python", "/opt/venv/bin/python"], check=True,
    )


def cleanup(variants: list[str]) -> None:
    expected = {image_tag(target, variant) for target in BUILD_TARGETS for variant in variants}
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
    parser.add_argument("--requirements-change", action="store_true",
                        help="allow a small dependency change and bound its install layer size")
    args = parser.parse_args()

    requirements_differ = False
    for name in ("requirements.txt", "manager_requirements.txt"):
        if requirements(args.before, name) != requirements(args.after, name):
            requirements_differ = True
            if not args.requirements_change:
                parser.error(f"{name} differs; choose two source-only revisions")
    if args.requirements_change and not requirements_differ:
        parser.error("--requirements-change requires different upstream requirements")

    run_id = uuid.uuid4().hex[:12]
    variants = [f"before-{run_id}", f"after-{run_id}"]
    try:
        before = build(args.before, variants[0], args.flavor)
        after = build(args.after, variants[1], args.flavor)
        baseline = before[BASELINE_TARGET]
        if baseline != after[BASELINE_TARGET]:
            raise AssertionError("upstream update rebuilt the cached dependency baseline")
        for target in TARGETS:
            old, new = before[target], after[target]
            if len(old) != len(new) or len(new) < 3:
                raise AssertionError(f"{target}: unexpected layer count")
            changed = [index for index, pair in enumerate(zip(old, new)) if pair[0] != pair[1]]
            if args.requirements_change:
                if old[:len(baseline)] != baseline or new[:len(baseline)] != baseline:
                    raise AssertionError(f"{target}: requirements change rebuilt the baseline")
                sizes = [check_requirements_layer(target, variant) for variant in variants]
                print(f"PASS {target}: cached baseline reused; requirements layers "
                      f"{sizes[0] / 1024**2:.1f}/{sizes[1] / 1024**2:.1f} MiB")
            else:
                if changed != [len(new) - 1]:
                    raise AssertionError(f"{target}: expected only source layer to change, got {changed}")
                print(f"PASS {target}: only source changed; {len(new) - 1} layers reused")
            for variant in variants:
                check_runtime(target, variant)
    finally:
        if not args.keep_images:
            cleanup(variants)


if __name__ == "__main__":
    main()
