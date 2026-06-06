from __future__ import annotations

import sys
from pathlib import Path

import pytest
from typer.testing import CliRunner

from uv2nix_template.models.config import AppConfig
from uv2nix_template.cli.context import AppContext

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "src"))


@pytest.fixture
def runner() -> CliRunner:
    return CliRunner()


@pytest.fixture
def cli():
    from uv2nix_template.cli.main import app

    return app


@pytest.fixture
def default_config() -> AppConfig:
    return AppConfig()


@pytest.fixture
def default_ctx(default_config: AppConfig) -> AppContext:
    return AppContext(verbose=False, config=default_config)
