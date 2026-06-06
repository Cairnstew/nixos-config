from __future__ import annotations

from uv2nix_template.models.config import AppConfig, SuccessResult, ErrorResult


def test_appconfig_empty_list_preserved() -> None:
    cfg = AppConfig()
    d = cfg.serialise()
    assert "extra_args" in d
    assert d["extra_args"] == []


def test_appconfig_default_log_level() -> None:
    cfg = AppConfig()
    assert cfg.log_level == "info"


def test_success_result_defaults() -> None:
    r = SuccessResult(message="done")
    assert r.ok is True
    assert r.message == "done"


def test_error_result_defaults() -> None:
    r = ErrorResult(message="fail")
    assert r.ok is False
    assert r.message == "fail"


def test_error_result_has_error_type() -> None:
    r = ErrorResult(message="not found", error_type="not_found")
    assert r.error_type == "not_found"
