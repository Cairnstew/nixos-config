from __future__ import annotations

from uv2nix_template.cli.context import AppContext
from uv2nix_template.models.config import AppConfig


def test_appcontext_defaults() -> None:
    ctx = AppContext()
    assert ctx.verbose is False
    assert ctx.config is None


def test_appcontext_with_config() -> None:
    cfg = AppConfig(log_level="debug")
    ctx = AppContext(verbose=True, config=cfg)
    assert ctx.verbose is True
    assert ctx.config is cfg
