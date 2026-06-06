from __future__ import annotations

import typer

from uv2nix_template.cli.commands.base import BaseCommand
from uv2nix_template.cli.context import AppContext
from uv2nix_template.models.config import AppConfig, BaseResult
from uv2nix_template.services.generator import GeneratorService

app = typer.Typer()


class InitCommand(BaseCommand):
    def run(self) -> BaseResult:
        svc = GeneratorService(self.ctx.config or AppConfig())
        return svc.initialise()


@app.callback(invoke_without_command=True)
def init(ctx: typer.Context) -> None:
    cmd = InitCommand(ctx.obj)
    cmd.handle_result(cmd.run())
