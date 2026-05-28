# Gotchas & Common Pitfalls

## Nix-Side Gotchas

### 1. `uv.lock` must exist for `nix build`

The Nix build reads `uv.lock` at evaluation time via `loadWorkspace`. If it's missing, evaluation fails with `No such file or directory`. Run `uv sync` first, and **commit `uv.lock`** to version control (remove it from `.gitignore` if needed — this template's `.gitignore` ignores it by default, which is wrong for uv2nix).

### 2. Infinite recursion with build-system overrides

The `config.uv2nix.buildSystemOverrides` option is **declared but currently unused** in the simplified `python-env.nix`. If you re-add a custom `mkBuildSystemOverlay`, be careful with `final` vs `prev` references — using both can create circular dependency loops during evaluation.

### 3. Python version mismatch

`modules/flake.nix` hardcodes `pkgs.python312`. If you change `requiresPython` to `>=3.13` but don't update the Python package, Nix will build against 3.12 while uv resolves for 3.13. Always update both:

```nix
config.project = {
  requiresPython = ">=3.13";
  # pythonPackage is set in the evalModules block — change pkgs.python312 → pkgs.python313
};
```

### 4. `writeShellApplication` is strict about shellcheck

All scripts passed to `writeShellApplication` are checked with shellcheck. Warnings like SC2155 (`Declare and assign separately`) are treated as errors. Use two-step assignment:

```bash
# BAD — fails shellcheck
export VAR=$(some_command)

# GOOD
var=$(some_command)
export VAR="$var"
```

### 5. `builtins.toJSON` flattens attribute names with dots

Nix attrsets like `{ "tool.ruff" = { ... }; }` are preserved as-is in JSON. The TOML writer expects dotted keys and converts them to `[tool.ruff]` sections. If you add a key with a dot in the name (not as a path separator), it will be misinterpreted.

## Python-Side Gotchas

### 6. Package name hyphens → underscores

In `modules/flake.nix`, `project.name` uses hyphens (e.g., `my-project`). Python imports use underscores (`my_project`). uv and hatchling handle the conversion automatically when building, but your source directory must use underscores.

### 7. Editable install requires `$REPO_ROOT`

The dev shell sets `REPO_ROOT` so the editable overlay can find your source. If you run `python -m my_project` outside the dev shell, `$REPO_ROOT` won't be set and the editable install will fall back to the non-editable build. Always use `nix develop` or set `REPO_ROOT` manually.

### 8. pyproject.toml is auto-generated — two sources of truth

The `pyproject.toml` is generated from `modules/pyproject.nix`. If you edit `pyproject.toml` directly, your changes will be overwritten on the next `nix run .#sync-pyproject`. To add deps, either:
- Use `uv add <pkg>` (updates `uv.lock` only, pyproject.toml stays in sync if uv updates it)
- Add to `modules/flake.nix` and regenerate

### 9. `dependency-groups.dev` uses PEP 735

Dev dependencies are declared under `[dependency-groups] dev = [...]` (PEP 735), not `[project.optional-dependencies] dev`. Older tools may not recognize this. uv and pytest do; coverage configuration in `pyproject.nix` checks for `"pytest-cov"` in the dev deps list (exact match, not substring).

## uv-Side Gotchas

### 10. uv downloads its own Python if not constrained

Set `UV_PYTHON_DOWNLOADS=never` and `UV_PYTHON` to the Nix-provided interpreter (already done in the dev shell). Without these, uv will download a generic CPython binary that won't run on NixOS.

### 11. `uv sync` creates a `.venv` in the project root

This `.venv` is not used by Nix builds — it's only for uv's own operations. The `.gitignore` ignores it, but be aware it exists. Delete it if disk space is a concern; `uv sync` will recreate it.

## hatchling Gotchas

### 12. Build backend changed in hatchling 1.28+

Hatchling moved its build backend from `hatchling.build.api` to `hatchling.build` in version 1.28+. If you pin hatchling to an older version in `pyproject.nix`, use the old path; for >=1.28, use `hatchling.build`.

## Test Gotchas

### 13. Test check requires `pytest` in dev dependencies

`nix flake check` runs `pytest --tb=short -q` in the check phase. If pytest isn't in `workspace.deps.all` (i.e., not in `dependency-groups.dev`), the check will fail with `pytest: command not found`.

### 14. Check derivation copies entire source tree

The `checks.tests` derivation sets `src = ../.`, copying the entire project into the Nix store. Large assets or `node_modules`-like directories will slow down the check. Add exclusion patterns via `src = pkgs.lib.cleanSource ../.` if needed.
