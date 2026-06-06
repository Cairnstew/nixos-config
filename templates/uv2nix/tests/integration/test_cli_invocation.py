from __future__ import annotations

import subprocess


def test_cli_help_exits_zero() -> None:
    result = subprocess.run(
        ["uv2nix-template", "--help"],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0
    assert "Usage" in result.stdout


def test_cli_init_exits_zero() -> None:
    result = subprocess.run(
        ["uv2nix-template", "init"],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0
