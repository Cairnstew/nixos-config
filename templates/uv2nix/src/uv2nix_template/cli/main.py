from __future__ import annotations

import typer

from uv2nix_template.cli.context import AppContext
from uv2nix_template.cli.commands import init, generate, validate

app = typer.Typer(no_args_is_help=True)
app.add_typer(init.app, name="init")
app.add_typer(generate.app, name="generate")
app.add_typer(validate.app, name="validate")


@app.callback()
def main(ctx: typer.Context, verbose: bool = False) -> None:
    ctx.ensure_object(dict)
    ctx.obj = AppContext(verbose=verbose)
