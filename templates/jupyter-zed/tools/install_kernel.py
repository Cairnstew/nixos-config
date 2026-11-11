#!/usr/bin/env python3
"""Install a Jupyter kernelspec pinned to this project's virtualenv.

Zed discovers notebook kernels by running ``jupyter kernelspec list``. The venv
already ships a ``python3`` spec, but its ``argv`` is a bare ``python`` resolved
through ``PATH`` — so which interpreter actually runs a cell depends on how the
editor was launched, and a notebook can silently import a different package
tree (or none at all) than the one under test.

This writes a spec whose ``argv`` names ``.venv/bin/python`` by absolute path,
so the kernel is the project's regardless of ``PATH``.

The flake's shellHook runs this on every ``nix develop``, so it is idempotent
and cheap. Run it by hand after ``uv sync`` recreates the venv:

    .venv/bin/python tools/install_kernel.py

The kernel name is ``[project].name`` from ``pyproject.toml`` — the same string
``.zed/settings.json`` selects under ``jupyter.kernel_selections.python``.
"""

from __future__ import annotations

import json
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VENV_PYTHON = ROOT / ".venv" / "bin" / "python"


def project_name() -> str:
    """``[project].name`` from pyproject.toml — the kernelspec id."""
    with (ROOT / "pyproject.toml").open("rb") as fh:
        return tomllib.load(fh)["project"]["name"]


def user_data_dir() -> Path:
    """``~/.local/share/jupyter/kernels`` unless a local data dir exists."""
    override = ROOT / ".jupyter-data"
    if override.is_dir():
        return override / "kernels"
    return Path.home() / ".local" / "share" / "jupyter" / "kernels"


def main() -> int:
    if not VENV_PYTHON.exists():
        print(f"no virtualenv at {VENV_PYTHON}\nrun: uv sync", file=sys.stderr)
        return 1

    name = project_name()
    target = user_data_dir() / name
    target.mkdir(parents=True, exist_ok=True)
    spec = {
        "argv": [
            str(VENV_PYTHON),
            "-m",
            "ipykernel_launcher",
            "-f",
            "{connection_file}",
        ],
        "display_name": f"{name} (.venv)",
        "language": "python",
        "metadata": {"debugger": True},
    }
    (target / "kernel.json").write_text(json.dumps(spec, indent=1) + "\n")
    print(f"installed kernelspec {name!r} -> {VENV_PYTHON}")
    print(f"  {target / 'kernel.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
