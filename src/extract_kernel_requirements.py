"""Keep native kernel pins independent of unrelated upstream requirements."""

from __future__ import annotations

from pathlib import Path
import re
import sys


KERNEL_PACKAGES = {"comfy-kitchen", "comfy-aimdo"}
NAME_RE = re.compile(r"^([A-Za-z0-9][A-Za-z0-9_.-]*)")


def extract_kernel_requirements(requirements: str) -> str:
    selected = []
    for raw_line in requirements.splitlines():
        line = raw_line.partition(" #")[0].strip()
        match = NAME_RE.match(line)
        if match is None:
            continue
        name = re.sub(r"[-_.]+", "-", match.group(1)).lower()
        if name in KERNEL_PACKAGES:
            selected.append(line)
    return "".join(line + "\n" for line in sorted(selected))


if __name__ == "__main__":
    source, destination = map(Path, sys.argv[1:])
    destination.write_text(
        extract_kernel_requirements(source.read_text(encoding="utf-8")),
        encoding="utf-8",
    )
