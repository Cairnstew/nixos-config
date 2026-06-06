from __future__ import annotations

import sys
import typer

from uv2nix_template.cli.context import AppContext
from uv2nix_template.models.config import BaseResult, ErrorResult


class BaseCommand:
    def __init__(self, ctx: AppContext) -> None:
        self.ctx = ctx

    def run(self) -> BaseResult:
        raise NotImplementedError

    def handle_result(self, result: BaseResult) -> None:
        if result.ok:
            typer.echo(result.message or "Done.")
        else:
            typer.secho(f"Error: {result.message}", fg=typer.colors.RED, err=True)
            raise typer.Exit(1)

    def abort(self, msg: str) -> None:
        typer.secho(f"Aborted: {msg}", fg=typer.colors.RED, err=True)
        raise typer.Exit(1)
