# Codebase Heat Map

## Hottest

### `modules/flake.nix` — Central orchestration
- **Why hot**: `project.*` options, dev shell wiring, app runner, test check. Edit here to change Python version, dev shell behavior, or add extra packages.
- **Complexity**: Medium. Nix module system with `evalModules` and per-system config.
- **Touch frequency**: Every project configuration change.

### `src/textual_app/app.py` — Main Textual App
- **Why hot**: Core TUI application. Screens, widgets, bindings, CSS live here.
- **Complexity**: Low initially; grows with app features.

### `pyproject.toml` — Project metadata
- **Why hot**: Dependencies, tool config (ruff, pytest), build settings. Edit directly.
- **Touch frequency**: Adding deps, changing tool config.

## Warm

### `modules/python-env.nix` — Package set construction
- **Why warm**: Overlay composition order matters. Change Python version or add custom overlays here.
- **Complexity**: Low. Stable.

### `src/textual_app/screens/` — Screen definitions
- **Why warm**: Individual screens and layouts.

### `tests/test_app.py` — Test suite
- **Why warm**: Async textual tests using `pilot.run_test()`.

## Cold

### `flake.nix` (top-level)
- Set once: input pins and system list.

### `.envrc`, `.gitignore`, `README.md`
- Set-and-forget.

## Data Flow

```
modules/flake.nix
    └─ reads project.* options → cfg
    └─ calls python-env.nix → basePythonSets, devEnv
    └─ constructs prodEnv / testEnv / devEnv
    └─ wires devShells, apps, packages, checks

modules/python-env.nix
    └─ reads uv.lock via uv2nix
    └─ applies pyproject-build-systems overlay
    └─ applies workspace.mkPyprojectOverlay
    └─ exposes basePythonSets + devEnv
```
