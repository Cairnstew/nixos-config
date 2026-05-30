# Gotchas & Common Pitfalls

## Nix-Side Gotchas

### 1. `uv.lock` must exist for `nix build`

The Nix build reads `uv.lock` at evaluation time via `loadWorkspace`. Run `uv sync` first, and **commit `uv.lock`** to version control.

### 2. Python version mismatch

`modules/flake.nix` hardcodes `pkgs.python312` in the evalModules block. To change Python, update both the Nix Python package and `requires-python` in `pyproject.toml`.

### 3. `writeShellApplication` is strict about shellcheck

Use two-step assignment for exports:

```bash
# BAD — fails shellcheck
export VAR=$(some_command)

# GOOD
var=$(some_command)
export VAR="$var"
```

### 4. Hatch build target must match source directory

```toml
[tool.hatch.build.targets.wheel]
packages = ["src/textual_app"]
```

If you rename the package directory, update this.

## Textual-Specific Gotchas

### 5. Textual requires a real terminal for full operation

In CI (non-TTY), some features may not work. Tests using `run_test()` simulate a terminal and work fine.

### 6. `pytest-asyncio` must be installed for async tests

Textual apps are async. The template includes it in dev dependencies. Without it, tests fail with `async test` errors.

### 7. `textual console` needs a separate terminal

Run `textual console` in one terminal, `textual run textual_app` in another. Both in the same dev shell.

### 8. Snapshot testing

Add `pytest-textual-snapshot` for snapshot tests:
```bash
uv add --dev pytest-textual-snapshot
```

### 9. Tree-sitter extras

The `syntax` optional dependencies include native tree-sitter packages. Add via:
```bash
uv add --optional syntax "tree-sitter>=0.25.0"
```

## uv-Side Gotchas

### 10. uv downloads its own Python if not constrained

The dev shell sets `UV_PYTHON_DOWNLOADS=never` and `UV_PYTHON` to the Nix interpreter. Without these, uv downloads a generic CPython.

### 11. `uv sync` creates `.venv`

The `.venv` is for uv's operations only, not used by Nix builds. Gitignored.

## Test Gotchas

### 12. Test check copies entire source tree

`checks.tests` sets `src = ../.`, copying the whole project into the Nix store. Use `pkgs.lib.cleanSource` if performance is an issue.

### 13. async tests need `asyncio_mode = auto`

The `pyproject.toml` sets `asyncio_mode = auto` in pytest ini_options. Without it, async test functions won't be detected.
