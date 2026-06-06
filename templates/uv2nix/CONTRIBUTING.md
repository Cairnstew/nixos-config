# Contributing

## Prerequisites

- Nix (with flakes enabled)
- `just` (optional, for recipe shortcuts)

## Quick start

```bash
nix develop
# or with just:
just nix-check
```

## Development loop

1. Make changes to `src/` or `nix/`
2. Run `just check` to lint, typecheck, and test
3. Run `just nix-check` to verify flake evaluation
4. Commit and open a PR

## Code style

- Python: ruff (format + lint) + mypy strict
- Nix: nixpkgs-fmt
- Pre-commit hooks enforce all of the above

## PR workflow

1. Create a feature branch from `main`
2. Make changes
3. Run `pre-commit run --all-files`
4. Push and open a pull request
5. CI runs lint, typecheck, tests, nix checks, and audit
6. All checks must pass before merge

## Adding a new CLI command

1. Create `src/uv2nix_template/cli/commands/<name>.py` with a `BaseCommand` subclass
2. Register the Typer sub-app in `cli/main.py`
3. Add tests in `tests/unit/` and `tests/integration/`
4. Add docs in `docs/reference/cli.md`

## Adding a new NixOS module option

1. Add the option in `nix/module.nix`
2. Add a test in `nix/checks.nix` (module-eval)
3. Document in `docs/reference/module.md`
