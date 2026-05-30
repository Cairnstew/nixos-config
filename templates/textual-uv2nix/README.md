# Textual TUI App with uv2nix

A modern [Textual](https://github.com/Textualize/textual) TUI application template using:
- **[Textual](https://textual.textualize.io/)** — Python framework for terminal user interfaces
- **[uv](https://docs.astral.sh/uv/)** — Fast Python package installer and resolver
- **[uv2nix](https://github.com/pyproject-nix/uv2nix)** — Nix integration for uv projects
- **[flake-parts](https://flake.parts/)** — Modular Nix flakes

## Quick Start

```bash
# Enter the development shell
nix develop

# Sync dependencies (creates uv.lock)
uv sync

# Run the Textual app
python -m textual_app
```

Or with textual devtools (in another terminal, run `textual console` first):

```bash
textual run textual_app
```

## Project Structure

```
.
├── flake.nix                  # Nix flake configuration
├── modules/
│   ├── flake.nix              # Options, shells, apps, packages, checks
│   └── python-env.nix         # uv2nix workspace → Python package set
├── src/
│   └── textual_app/           # Your Textual TUI app
│       ├── __init__.py
│       ├── __main__.py        # Entry point (python -m textual_app)
│       ├── app.py             # Main App class
│       └── screens/           # Screen definitions
├── tests/
├── pyproject.toml             # Python project metadata — edit directly
├── uv.lock                    # Lockfile — commit this
├── .envrc                     # direnv integration
└── .github/                   # CI workflows
```

## Commands

| Command | Description |
|---|---|
| `nix develop` | Enter dev shell (editable install + uv + textual-dev) |
| `nix build` | Build production environment |
| `nix run` | Run the TUI app |
| `nix flake check` | Build + run tests |
| `uv add <pkg>` | Add dependency (updates both pyproject.toml and uv.lock) |
| `uv sync` | Sync dependencies from lockfile |

## Textual Dev Tools

| Command | Description |
|---|---|
| `textual run <module>` | Run app with devtools |
| `textual console` | Devtools console (separate terminal) |
| `textual colors` | Preview color schemes |
| `textual keys` | Interactive key tester |
| `textual diagnose` | System diagnostics |
| `textual screenshot` | Capture app screenshot |
| `textual easing` | Easing function demo |

## Customization

Edit `pyproject.toml` to change the app name, dependencies, versions, and tool config. Run `uv lock` after changes, then `nix build` to verify.

## License

MIT
