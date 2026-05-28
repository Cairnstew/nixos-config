# Project Structure

```
.
├── flake.nix                   # Top-level flake — pins inputs from GitHub
├── flake.lock                  # Locked flake inputs (auto-generated)
├── pyproject.toml              # Python project metadata (auto-generated)
├── uv.lock                     # Pinned dependency versions (uv)
├── .envrc                      # direnv: auto-enters dev shell on cd
├── .gitignore
├── AGENTS.md                   # Guidance for AI coding agents
├── HEATMAP.md                  # Codebase complexity & hot spots
├── GOTCHAS.md                  # Common pitfalls when working with this template
├── README.md                   # Quick-start and overview
│
├── modules/
│   ├── flake.nix               # Central module: options, shells, apps, packages, checks
│   ├── python-env.nix          # uv2nix workspace → Nix Python package set
│   └── pyproject.nix           # Generates pyproject.toml from Nix config
│
├── src/
│   └── my_project/             # Python package (rename in modules/flake.nix)
│       ├── __init__.py         # Package metadata
│       ├── __main__.py         # Entry point (python -m my_project)
│       └── utils.py            # Example module
│
└── tests/
    ├── __init__.py
    ├── conftest.py
    └── test_utils.py           # Example tests
```

## Architecture Overview

### Nix Layer

The Nix configuration is split across three files in `modules/`, each with a single responsibility:

```
flake.nix (top-level)
  └─ imports ./modules/flake.nix  (options, shells, apps, checks)
       ├─ imports ./python-env.nix  (uv2nix workspace → Python set)
       └─ imports ./pyproject.nix   (pyproject.toml generator)
```

| File | Role |
|---|---|
| `modules/flake.nix` | Defines `project.*` options, builds dev shells, app runner, test check |
| `modules/python-env.nix` | Loads `uv.lock`, overlays build systems, produces `basePythonSets` and `devEnv` |
| `modules/pyproject.nix` | Converts Nix config to `pyproject.toml` via an embedded Python TOML writer |

### Python Layer

The Python source lives under `src/<package_name>/`.  The package name is set via `config.project.name` in `modules/flake.nix` (hyphens in the Nix name become underscores in Python imports — uv/hatchling handle this automatically).

### Data Flow

1. `modules/flake.nix` reads `project.*` options → produces `cfg`
2. `cfg` is passed to `python-env.nix` (loads uv.lock, builds package sets) and `pyproject.nix` (generates pyproject.toml)
3. Virtual envs (`prodEnv`, `testEnv`, `devEnv`) are created from the package sets using `workspace.deps.default` (runtime) or `workspace.deps.all` (including dev)
4. `devShells.default` wraps `devEnv` + `uv` + extras
5. `checks.tests` wraps `testEnv` and runs `pytest`

## Key Design Decisions

- **uv2nix** for Python dependency management — single source of truth is `uv.lock`
- **flake-parts** for modular Nix flake structure — extensible without editing top-level flake
- **hatchling** build backend — modern, fast, PEP 621 compliant
- **pyproject.toml is auto-generated** — edit Nix config, not TOML directly (or use `uv add`)
- **Editable install** in dev shell — source changes take effect immediately
