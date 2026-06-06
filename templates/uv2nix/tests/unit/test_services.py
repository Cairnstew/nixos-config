from __future__ import annotations

from uv2nix_template.models.config import AppConfig
from uv2nix_template.services.base import BaseService
from uv2nix_template.services.config import ConfigService


def test_baseservice_takes_config() -> None:
    cfg = AppConfig()
    svc = BaseService(cfg)
    assert svc.config is cfg


def test_configservice_read_returns_config() -> None:
    cfg = AppConfig(log_level="debug")
    svc = ConfigService(cfg)
    result = svc.read()
    assert result.log_level == "debug"


def test_configservice_write_updates_config() -> None:
    cfg = AppConfig()
    svc = ConfigService(cfg)
    new_cfg = AppConfig(log_level="error")
    svc.write(new_cfg)
    assert svc.config.log_level == "error"
