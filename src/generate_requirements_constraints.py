from __future__ import annotations

import os
import re
import subprocess
import sys
import tempfile
from collections import defaultdict
from importlib import metadata
from pathlib import Path

from packaging.markers import default_environment
from packaging.requirements import Requirement
from packaging.specifiers import SpecifierSet
from packaging.version import Version


UPPER_BOUND_OPERATORS = {"<", "<=", "~="}
NAME_RE = re.compile(r"^\s*([A-Za-z0-9][A-Za-z0-9_.-]*)")


def normalize_name(name: str) -> str:
    return re.sub(r"[-_.]+", "-", name).lower()


def requirement_name(requirement_line: str) -> str | None:
    match = NAME_RE.match(requirement_line)
    if match is None:
        return None
    return normalize_name(match.group(1))


def active_lines(path: Path) -> list[str]:
    if not path.exists():
        return []

    lines = []
    for raw_line in path.read_text().splitlines():
        line = raw_line.partition("#")[0].strip()
        if line:
            lines.append(line)
    return lines


def active_installed_upper_bounds() -> dict[str, list[str]]:
    env = default_environment()
    bounds: dict[str, list[str]] = defaultdict(list)

    for dist in metadata.distributions():
        for raw_requirement in dist.requires or []:
            requirement = Requirement(raw_requirement)
            if requirement.marker is not None and not requirement.marker.evaluate(env):
                continue
            if not any(
                specifier.operator in UPPER_BOUND_OPERATORS
                for specifier in requirement.specifier
            ):
                continue

            bounds[normalize_name(requirement.name)].append(str(requirement.specifier))

    return bounds


def direct_requirements(paths: list[Path]) -> dict[str, list[str]]:
    requirements: dict[str, list[str]] = defaultdict(list)

    for path in paths:
        for line in active_lines(path):
            try:
                requirement = Requirement(line)
            except Exception:
                continue
            requirements[normalize_name(requirement.name)].append(line)

    return requirements


def manager_style_compile(
    requirement_line: str, requirements_path: Path, manager_requirements_path: Path
) -> str | None:
    with tempfile.TemporaryDirectory(prefix="dependency-risk-") as tmp:
        tmp_path = Path(tmp)
        input_path = tmp_path / "node-requirements.txt"
        output_path = tmp_path / "resolved-requirements.txt"
        input_path.write_text(requirement_line + "\n")

        command = [
            "uv",
            "pip",
            "compile",
            str(input_path),
            "--constraint",
            str(requirements_path),
        ]
        if manager_requirements_path.exists():
            command.extend(["--constraint", str(manager_requirements_path)])
        command.extend(
            [
                "--python",
                sys.executable,
                "--output-file",
                str(output_path),
                "--quiet",
            ]
        )

        result = subprocess.run(command, capture_output=True, text=True, timeout=120)
        if result.returncode != 0:
            raise RuntimeError(result.stderr.strip() or result.stdout.strip())

        name = normalize_name(Requirement(requirement_line).name)
        for line in active_lines(output_path):
            resolved_requirement = Requirement(line)
            if normalize_name(resolved_requirement.name) != name:
                continue
            for specifier in resolved_requirement.specifier:
                if specifier.operator == "==":
                    return specifier.version

    return None


def failed_bounds(name: str, resolved_version: str, bounds: list[str]) -> list[str]:
    version = Version(resolved_version)
    return [
        specifier
        for specifier in bounds
        if not Requirement(f"{name}{specifier}").specifier.contains(
            version, prereleases=True
        )
    ]


def existing_constraints(path: Path) -> dict[str, str]:
    constraints = {}
    for line in active_lines(path):
        try:
            requirement = Requirement(line)
        except Exception:
            continue
        constraints[normalize_name(requirement.name)] = line
    return constraints


def generate_constraints(base_path: Path, output_path: Path) -> dict[str, str]:
    requirements_path = base_path / "requirements.txt"
    manager_requirements_path = base_path / "manager_requirements.txt"
    direct = direct_requirements(
        [
            requirements_path,
            manager_requirements_path,
            base_path / "requirements.cached.txt",
        ]
    )
    bounds = active_installed_upper_bounds()
    constraints = existing_constraints(output_path)

    for name in sorted(bounds):
        requirement_line = direct[name][0] if name in direct else name
        resolved_version = manager_style_compile(
            requirement_line, requirements_path, manager_requirements_path
        )
        if resolved_version is None:
            continue

        violating_bounds = failed_bounds(name, resolved_version, bounds[name])
        if not violating_bounds:
            continue

        direct_requirement = Requirement(requirement_line)
        specifier_parts = [
            part
            for part in [str(direct_requirement.specifier), *violating_bounds]
            if part
        ]
        combined_specifier = SpecifierSet(",".join(specifier_parts))
        constraints[name] = f"{direct_requirement.name}{combined_specifier}"

    return constraints


def apply_constraints(constraints_path: Path, requirements_path: Path) -> None:
    constraints = active_lines(constraints_path)
    requirements = requirements_path.read_text().splitlines()
    requirement_indexes = {
        name: index
        for index, line in enumerate(requirements)
        if (name := requirement_name(line)) is not None
    }

    for constraint in constraints:
        name = requirement_name(constraint)
        if name is None:
            continue

        existing_index = requirement_indexes.get(name)
        if existing_index is None:
            requirement_indexes[name] = len(requirements)
            requirements.append(constraint)
        else:
            requirements[existing_index] = constraint

    requirements_path.write_text("\n".join(requirements) + "\n")


def main() -> int:
    base_path = Path(os.environ.get("COMFYUI_PATH", "/comfyui"))
    output_path = Path(
        sys.argv[1] if len(sys.argv) > 1 else "/opt/offloadr/constraints/comfyui.txt"
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)

    constraints = generate_constraints(base_path, output_path)
    header = [
        "# Generated during image build from installed package metadata.",
        "# These constraints prevent Manager-style dependency sync from selecting",
        "# versions outside upper bounds declared by already-installed packages.",
    ]
    lines = header + [constraints[name] for name in sorted(constraints)]
    output_path.write_text("\n".join(lines) + "\n")

    if len(sys.argv) > 2:
        apply_constraints(output_path, Path(sys.argv[2]))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
