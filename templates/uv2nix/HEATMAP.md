# Codebase Heat Map

Hotter components = more frequently modified or higher complexity.

## 🔥 Hottest

### `modules/flake.nix` — Central orchestration
- **Why hot**: All project options live here (`project.name`, `dependencies`, `devDependencies`, `scripts`, etc.). Adding a dep, changing Python version, or wiring new shells/apps/checks means editing this file.
- **Complexity**: Medium-high. Nix module system with `evalModules`, option declarations, and per-system config.
- **Touch frequency**: Every project configuration change.

### `modules/pyproject.nix` — pyproject.toml generator
- **Why hot**: The embedded TOML writer is custom Python code. If a new tool config section is needed (`[tool.mypy]`, `[tool.black]`, etc.), add it in the Nix attrset here. The writer itself has subtle logic for dotted-key sub-sections. Also handles `tool.hatch.build.targets.wheel.packages` which must match the source layout.
- **Complexity**: Medium. Python TOML serialization is non-trivial; the inline-table vs section logic is easy to get wrong.
- **Risk areas**: Nested dicts become dotted sub-sections; empty dicts are skipped; `lib.optionalAttrs` gates conditional sections. Hatch build target `packages` must be correct for the source layout.

## 🔥 Warm

### `modules/python-env.nix` — Package set construction
- **Why warm**: Overlay composition order matters. Adding new overlays or changing `sourcePreference` affects build behavior. The editable overlay is layered on top for the dev shell.
- **Complexity**: Low now (simplified from earlier recursion issues). Stable unless you need custom overlays.

### `src/my_project/__main__.py` — Application entry point
- **Why warm**: Entry point logic grows with the project. CLI argument parsing, logging setup, etc. land here.
- **Complexity**: Low initially; grows with app features.

## ❄️ Cold

### `flake.nix` (top-level)
- Set once: input pins and system list. Rarely touched after initialization.

### `tests/`
- Cold as a template; will heat up as real tests are written.

### `.envrc`, `.gitignore`, `README.md`
- Set-and-forget configuration files.

## Dependency Graph

```
modules/flake.nix
    ├── defines project.* options (name, deps, python, scripts, etc.)
    ├── calls python-env.nix  →  produces basePythonSets, devEnv
    ├── calls pyproject.nix   →  produces TOML writer + JSON data
    ├── constructs prodEnv / testEnv / devEnv from workspace.deps
    └── wires devShells, apps, packages, checks

modules/python-env.nix
    ├── reads uv.lock via uv2nix.lib.workspace.loadWorkspace
    ├── applies pyproject-build-systems overlay
    ├── applies workspace.mkPyprojectOverlay
    └── exposes basePythonSets + devEnv (with editable overlay)

modules/pyproject.nix
    ├── reads project.* options
    ├── builds attrs attrset (build-system, project, tool.*, etc.)
    ├── includes hatch build target wheel.packages for src/ layout
    ├── emits JSON + TOML writer script
    └── used by sync-pyproject app and bootstrap shell
```

## Change Frequency Estimates

| Component | Initial setup | Per-feature | Per-dep | Per-tool-config |
|---|---|---|---|---|
| `modules/flake.nix` | Heavy | Medium | Light | Light |
| `modules/python-env.nix` | Once | Never | Never | Never |
| `modules/pyproject.nix` | Once | Never | Never | Medium (tool config, hatch targets) |
| `src/my_project/` | Light | Heavy | Light | Never |
| `tests/` | Light | Medium | Never | Never |
| `pyproject.toml` | Auto | Auto | Auto | Auto |
