# Agent Guide

Guidance for AI coding agents working with this Textual + uv2nix template.

## Project Identity

- **Textual TUI app** managed with **uv** and **Nix** (uv2nix).
- Flake-based build with `flake-parts` for modular configuration.
- Build backend: **hatchling**.
- Runtime dependency: **textual >= 8.0.0**.
- Python version: **3.12**.

## Key Files

| File | Purpose |
|---|---|
| `flake.nix` | Top-level flake — pins inputs, imports `modules/flake.nix` |
| `modules/flake.nix` | Options, shells, apps, packages, checks |
| `modules/python-env.nix` | uv2nix workspace → Python package set |
| `pyproject.toml` | Python project metadata — edit directly |
| `uv.lock` | Lockfile — do not edit by hand, commit it |
| `src/textual_app/` | Python package source (Textual app) |
| `tests/` | Test suite (pytest + pytest-asyncio) |
| `.envrc` | direnv — auto-enters dev shell on cd |

## Workflow

```
nix develop                  # enter dev shell
uv sync                      # sync deps (one-time setup)
nix build                    # build production environment
nix run                      # run the TUI app
nix flake check              # run all checks (including tests)
```

## Adding Dependencies

Edit `pyproject.toml` directly, then run:

```bash
uv lock                      # regenerate uv.lock
nix build                    # verify
```

Or use uv:

```bash
uv add <pkg>                 # adds to pyproject.toml + updates uv.lock
uv add --dev <pkg>           # adds dev dependency
```

## Running the Textual App

```bash
nix run                    # run via nix app
python -m textual_app      # run with dev shell Python
textual run textual_app    # run with textual devtools
textual console            # open devtools console (separate terminal)
```

## Textual Dev Tools (in dev shell)

- `textual run` — run with live preview
- `textual console` — devtools console
- `textual colors` — color preview
- `textual keys` — interactive key tester
- `textual diagnose` — system diagnostics
- `textual screenshot` — capture app screenshots
- `textual easing` — easing function demo

## Important Nix Commands

```bash
nix build                    # package
nix run                      # run the TUI app
nix develop                  # dev shell (editable install + uv + textual-dev)
nix flake check              # full check (build + tests)
```

## Dev Shell Behavior

- `$REPO_ROOT` set to git root (or CWD).
- `UV_NO_SYNC=1` — uv won't auto-sync.
- `UV_PYTHON_DOWNLOADS=never` — must use Nix Python.
- Editable install of the project package is active.
- `textual-dev` CLI tools available.
- `.env` loaded automatically via direnv's `dotenv`.

## Testing

Tests run via `nix flake check` (builds test env, runs `pytest --tb=short -q`).
`pytest-asyncio` available with `asyncio_mode = auto`.

## Build System Overrides

If a package in `uv.lock` fails to build, add overrides via `config.uv2nix.buildSystemOverrides` in `modules/flake.nix`:

```nix
config.uv2nix.buildSystemOverrides = {
  some-package = { setuptools = [ ]; cython = [ ]; };
};
```
