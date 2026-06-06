from __future__ import annotations

from typer.testing import CliRunner


def test_cli_help(runner: CliRunner, cli) -> None:
    result = runner.invoke(cli, ["--help"])
    assert result.exit_code == 0
    assert "Usage" in result.stdout


def test_cli_init(runner: CliRunner, cli) -> None:
    result = runner.invoke(cli, ["init"])
    assert result.exit_code == 0


def test_cli_generate(runner: CliRunner, cli) -> None:
    result = runner.invoke(cli, ["generate"])
    assert result.exit_code == 0


def test_cli_validate(runner: CliRunner, cli) -> None:
    result = runner.invoke(cli, ["validate"])
    assert result.exit_code == 0


def test_cli_verbose_flag(runner: CliRunner, cli) -> None:
    result = runner.invoke(cli, ["--verbose", "init"])
    assert result.exit_code == 0
