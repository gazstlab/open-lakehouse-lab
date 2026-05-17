"""Valida arquivos requirements contra declaracoes de dependencias do pyproject."""

from __future__ import annotations

import difflib
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PYPROJECT = ROOT / "pyproject.toml"


def load_pyproject() -> dict:
    with PYPROJECT.open("rb") as file:
        return tomllib.load(file)


def load_requirements(path: Path) -> list[str]:
    return [
        line.strip()
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]


def format_diff(
    expected: list[str],
    actual: list[str],
    expected_name: str,
    actual_name: str,
) -> str:
    return "\n".join(
        difflib.unified_diff(
            expected,
            actual,
            fromfile=expected_name,
            tofile=actual_name,
            lineterm="",
        )
    )


def check_requirements(
    *,
    expected: list[str],
    requirements_path: Path,
    expected_name: str,
) -> bool:
    if not requirements_path.exists():
        print(f"{requirements_path.name} nao existe.", file=sys.stderr)
        return False

    actual = load_requirements(requirements_path)
    if actual == expected:
        return True

    print(
        f"{requirements_path.name} nao esta sincronizado com {expected_name}.",
        file=sys.stderr,
    )
    diff = format_diff(
        expected,
        actual,
        expected_name,
        requirements_path.name,
    )
    if diff:
        print(diff, file=sys.stderr)
    return False


def main() -> int:
    pyproject = load_pyproject()
    project = pyproject.get("project", {})
    optional_dependencies = project.get("optional-dependencies", {})

    checks = [
        check_requirements(
            expected=project.get("dependencies", []),
            requirements_path=ROOT / "requirements.txt",
            expected_name="pyproject.toml project.dependencies",
        ),
        check_requirements(
            expected=optional_dependencies.get("dev", []),
            requirements_path=ROOT / "requirements-dev.txt",
            expected_name="pyproject.toml project.optional-dependencies.dev",
        ),
    ]

    return 0 if all(checks) else 1


if __name__ == "__main__":
    raise SystemExit(main())
