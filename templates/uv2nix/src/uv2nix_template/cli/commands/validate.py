from __future__ import annotations

import typer

from uv2nix_template.cli.commands.base import BaseCommand
from uv2nix_template.cli.context import AppContext
from uv2nix_template.models.config import AppConfig, BaseResult
from uv2nix_template.services.validator import ValidatorService

app = typer.Typer()


class ValidateCommand(BaseCommand):
    path: str = ""

    def run(self) -> BaseResult:
        svc = ValidatorService(self.ctx.config or AppConfig())
        return svc.validate(self.path)


@app.callback(invoke_without_command=True)
def validate(ctx: typer.Context, path: str = typer.Argument(".")) -> None:
    cmd = ValidateCommand(ctx.obj)
    cmd.path = path
    cmd.handle_result(cmd.run())
