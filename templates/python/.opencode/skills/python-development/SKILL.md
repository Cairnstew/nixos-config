---
name: python-development
description: Python development with Nix and uv/poetry support
---

## What I do

Guide Python development within a Nix flake environment.

## Project Structure

```
.
├── src/
│   └── main.py         # Entry point
├── flake.nix           # Nix flake
├── pyproject.toml      # Python project config (optional)
└── .envrc              # direnv integration
```

## Common Tasks

### Setup project with uv

```bash
uv init
uv add <package>
```

### Setup project with poetry

```bash
poetry init
poetry add <package>
```

### Run the application

```bash
python src/main.py
# Or with Nix
nix run
```

### Development shell

```bash
nix develop
# Or with direnv
direnv allow
```

### Type checking

```bash
mypy src/
```

### Linting

```bash
ruff check src/
ruff format src/
```

### Testing

```bash
pytest
```

## Key Tools Available

- `python3` - Python interpreter
- `uv` - Fast Python package installer
- `ruff` - Fast Python linter
- `mypy` - Static type checker
- `pytest` - Testing framework

## Virtual Environments

With uv:
```bash
uv venv
source .venv/bin/activate
```

With poetry:
```bash
poetry shell
```

## Packaging for Nix

To build as a Nix package, update the `installPhase` in `flake.nix`:

```nix
installPhase = ''
  mkdir -p $out/bin
  cp -r src $out/lib
  makeWrapper ${pkgs.python3}/bin/python $out/bin/my-app \
    --add-flags "$out/lib/main.py"
'';
```
