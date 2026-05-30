# Agent Guide

Guidance for AI coding agents (opencode, Copilot, etc.) working with this flake template.

## Project Identity

- **Python project** managed with **uv** and **Nix** (uv2nix).
- Flake-based build with `flake-parts` for modular configuration.
- Build backend: **hatchling**.
- Python version: **3.12** (configurable in `modules/flake.nix`).

## Key Files

| File | Purpose |
|---|---|
| `flake.nix` | Top-level flake — pins inputs, imports `modules/flake.nix` |
| `modules/flake.nix` | All options, shells, apps, packages, checks |
| `modules/python-env.nix` | uv2nix workspace → Python package set |
| `modules/pyproject.nix` | Generates `pyproject.toml` from Nix config |
| `pyproject.toml` | Auto-generated — edit `modules/flake.nix` then run `nix run .#sync-pyproject` |
| `uv.lock` | Lockfile — must be committed, do not edit by hand |
| `src/my_project/` | Python package source |
| `tests/` | Test suite (pytest) |
| `.envrc` | direnv config — auto-enters dev shell, loads `.env` |
| `.env` | Local secrets/config (gitignored) |

## Workflow (in order)

```
nix run .#sync-pyproject   # regenerate pyproject.toml after config changes
uv sync                    # update uv.lock after dependency changes
nix build                  # build production environment
nix run                    # run the application
nix flake check            # run all checks (including tests)
```

## Adding Dependencies

1. Add to `modules/flake.nix` under `config.project.dependencies` (runtime) or `config.project.devDependencies` (dev).
2. Run `nix run .#sync-pyproject` to regenerate `pyproject.toml`.
3. Run `uv sync` to regenerate `uv.lock`.
4. Run `nix build` or `nix flake check` to verify.

Alternatively, use `uv add <pkg>` / `uv add --dev <pkg>` and commit the updated `uv.lock`.

## Adding Optional Dependencies

Use `config.project.optionalDependencies` in `modules/flake.nix`:

```nix
config.project.optionalDependencies = {
  web = [ "fastapi>=0.115" ];
  db = [ "sqlalchemy>=2.0" ];
};
```

This generates `[project.optional-dependencies]` in `pyproject.toml`.

## Adding System Packages to the Dev Shell

Use `config.project.extraDevPackages` to add system-level tools (CLIs, services, etc.):

```nix
config.project.extraDevPackages = pkgs: [ pkgs.postgresql pkgs.redis ];
```

## Setting Shell Environment Variables

Use `config.project.shellEnv` in `modules/flake.nix`:

```nix
config.project.shellEnv = {
  DATABASE_URL = "postgresql://localhost/mydb";
};
```

For secrets, place them in `.env` (loaded automatically by `.envrc` via direnv).

## Build System Overrides

If a package in `uv.lock` fails to build because its build-system deps aren't declared, add overrides via `config.uv2nix.buildSystemOverrides` in `modules/flake.nix`:

```nix
config.uv2nix.buildSystemOverrides = {
  some-package = { setuptools = [ ]; cython = [ ]; };
};
```

## Common Nix Commands

```bash
nix build                  # package (alias for packages.default)
nix run                    # run the app
nix run .#sync-pyproject   # regenerate pyproject.toml
nix develop                # dev shell (with editable install + uv)
nix develop .#bootstrap    # bootstrap shell (for initial setup)
nix flake check            # full check (build + tests)
nix build .#my-project-dev # dev environment explicitly
```

## Dev Shell Behavior

- `$REPO_ROOT` is set to the git root (or CWD fallback).
- `UV_NO_SYNC=1` to prevent uv from syncing automatically.
- `UV_PYTHON_DOWNLOADS=never` — must use Nix-provided Python.
- Editable install of the project package is active (changes to `src/` picked up live).
- `.env` file is **not** automatically loaded in `nix develop` (only via direnv's `dotenv`). Add shellHook sourcing if needed.

## Testing

Tests run via `nix flake check` (builds test environment, runs `pytest --tb=short -q`).  All dev dependencies from `dependency-groups.dev` are available.

## Python Backend

The TOML writer in `modules/pyproject.nix` emits dotted-key sections (`[tool.ruff]`). Nested dicts become sub-sections. Empty dicts are omitted.  `build-system` uses the `hatchling.build` backend (not the deprecated `hatchling.build.api`).

Hatch build targets in `pyproject.nix` include `tool.hatch.build.targets.wheel.packages` pointing to `src/${cfg.name}`. If you change the source layout, update this config.

## .envrc

If `direnv` is installed, `direnv allow` auto-enters the dev shell on `cd`.  It also loads `.env` via `dotenv` if present — variables from `.env` are available in the shell environment.
