# Project Structure

```
.
├── flake.nix                   # Top-level flake — pins inputs from GitHub
├── flake.lock                  # Locked flake inputs (auto-generated)
├── pyproject.toml              # Python project metadata — edit directly
├── uv.lock                     # Pinned dependency versions (uv)
├── .envrc                      # direnv: auto-enters dev shell on cd
├── .gitignore
├── AGENTS.md                   # AI agent guidance
├── HEATMAP.md                  # Hot spots
├── GOTCHAS.md                  # Common pitfalls
├── README.md                   # Quick-start and overview
├── STRUCTURE.md                # This file
│
├── modules/
│   ├── flake.nix               # Options, shells, apps, packages, checks
│   └── python-env.nix          # uv2nix workspace → Python package set
│
├── src/
│   └── textual_app/            # Textual TUI application
│       ├── __init__.py
│       ├── __main__.py
│       ├── app.py              # App class with screens, bindings, CSS
│       └── screens/
│
└── tests/
    ├── __init__.py
    └── test_app.py             # Async textual tests (pytest-asyncio)
```

## Architecture

### Nix Layer

```
flake.nix (top-level)
  └─ imports ./modules/flake.nix  (options, shells, apps, checks)
       └─ imports ./python-env.nix  (uv2nix workspace → Python set)
```

| File | Role |
|---|---|
| `modules/flake.nix` | Defines `project.*` options, builds dev shells, app runner, test check |
| `modules/python-env.nix` | Loads `uv.lock`, overlays build systems, produces `basePythonSets` and `devEnv` |

### Python Layer

The Textual app source lives under `src/<package_name>/`. The package is `textual_app` by default (configured in `pyproject.toml`).

### Data Flow

1. `modules/flake.nix` reads `project.*` options → `cfg`
2. `python-env.nix` loads `uv.lock`, applies overlays → `basePythonSets` + `devEnv`
3. Virtual envs (`prodEnv`/`testEnv`/`devEnv`) from workspace deps
4. `devShells.default` = `devEnv` + `uv` + extra packages + env vars
5. `checks.tests` = `testEnv` + `pytest`

## Key Design Decisions

- **Textual** for terminal UI — modern, async, CSS-styled TUI framework
- **uv2nix** for Python deps — single source of truth is `uv.lock`
- **flake-parts** for modular Nix flake structure
- **hatchling** build backend — PEP 621 compliant
- **pyproject.toml is static** — edit it directly (or use `uv add`)
- **Editable install** in dev shell — source changes take effect immediately
- **pytest-asyncio** for testing — async tests with `asyncio_mode = auto`
