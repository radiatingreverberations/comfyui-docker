from __future__ import annotations

import os
import re
import sys
from collections import defaultdict
from importlib import metadata
from pathlib import Path

from packaging.markers import default_environment
from packaging.requirements import Requirement
from packaging.specifiers import SpecifierSet


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


def active_installed_dependency_constraints() -> dict[str, tuple[str, list[str]]]:
    env = default_environment()
    constraints: dict[str, tuple[str, list[str]]] = {}

    for dist in metadata.distributions():
        for raw_requirement in dist.requires or []:
            requirement = Requirement(raw_requirement)
            if requirement.marker is not None and not requirement.marker.evaluate(env):
                continue
            if not requirement.specifier:
                continue

            name = normalize_name(requirement.name)
            display_name, specifiers = constraints.setdefault(
                name, (requirement.name, [])
            )
            specifiers.append(str(requirement.specifier))

    return constraints


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
    dependency_constraints = active_installed_dependency_constraints()
    constraints = existing_constraints(output_path)

    for name in sorted(dependency_constraints):
        display_name, installed_specifiers = dependency_constraints[name]
        specifier_parts = [
            *(
                [str(Requirement(direct[name][0]).specifier)]
                if name in direct
                else []
            ),
            *installed_specifiers,
        ]
        if name in constraints:
            specifier_parts.append(str(Requirement(constraints[name]).specifier))
            display_name = Requirement(constraints[name]).name

        specifier_parts = [part for part in specifier_parts if part]
        combined_specifier = SpecifierSet(",".join(specifier_parts))
        constraints[name] = f"{display_name}{combined_specifier}"

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
        "# versions outside bounds declared by already-installed packages.",
    ]
    lines = header + [constraints[name] for name in sorted(constraints)]
    output_path.write_text("\n".join(lines) + "\n")

    if len(sys.argv) > 2:
        apply_constraints(output_path, Path(sys.argv[2]))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
