# Gotchas

## uv2nix

### uv.lock required for evaluation
The flake won't evaluate without a `uv.lock`. Use `nix develop .#bootstrap` to get Python + uv, then run `uv lock`.

### uv.lock doesn't contain build systems
uv [doesn't lock build systems](https://github.com/astral-sh/uv/issues/5190). uv2nix uses `pyproject-build-systems` overlay to supply them. If a build system isn't in that repo, you must supply it via an overlay.

### Don't use `uv run` inside the dev shell
`uv run` creates its own venv, defeating uv2nix's provisioning. The dev shell already makes all scripts/entry points available directly.

### Don't filter sources at workspace root
`uv2nix.lib.workspace.loadWorkspace` reads from the workspace root at evaluation time. Filtering there causes IFD and breaks editables. Filter per-package instead.

### Editable packages need `REPO_ROOT`
The editable overlay uses `$REPO_ROOT` to locate the source tree. The dev shell `shellHook` sets it via `git rev-parse --show-toplevel`. If you're not in a git repo, set it manually.

### `unset PYTHONPATH`
Nixpkgs Python builders set `PYTHONPATH`, which leaks into unrelated builds. Always unset it in the dev shell `shellHook`.

### MacOS wheels may not match
Nixpkgs doesn't know your actual macOS version. Set `darwinSdkVersion` explicitly in the `stdenv` override if wheel compatibility fails.

## uv / Python

### setuptools.backends._legacy is gone
`setuptools.backends._legacy._Backend` was removed in modern setuptools. Use `setuptools.build_meta` instead.

### `tool.uv.dev-dependencies` is deprecated
Use `[dependency-groups] dev = [...]` instead (modern uv convention).

## Nix

### Python version mismatch
If `flake.nix` uses `pkgs.python3` but `pyproject.toml` says `requires-python = ">=3.12"`, you may get interpreter incompatibilities. Either pin `python = pkgs.python312` in `flake.nix`, or use the auto-filter approach from the uv2nix docs.

### result symlinks
`nix build` creates `result` symlinks. These are in `.gitignore` but can confuse tooling if you build inside the repo.

### Flake lock drift
After changing flake inputs, run `nix flake lock` to update `flake.lock`. Otherwise you'll silently use the old pinned versions.

## CI / GitHub Actions

### `flake-checker-action` telemetry
The `flake-checker-action` (used in setup-nix) phones home to Determinate Systems' telemetry service. This is fine for most projects — worth knowing for audit-sensitive environments.

### Test tiers are detected by directory presence
The CI `detect` job checks if `tests/$tier/test_*.py` exists. If you add a new tier directory, it won't be run until you add it to the `for dir in` loop in `ci.yml`.

### `nix develop .#bootstrap` vs `nix develop`
Lint and typecheck use `.#bootstrap` (fast, no uv2nix venv). Tests use `nix develop` (full hermetic environment). If lint/typecheck fail but tests pass, the issue is tool version mismatch between the two shells — check both have the same ruff/mypy version.

### `continue-on-error` for integration/e2e
`unit` tests are required (hard failure). `integration` and `e2e` use `continue-on-error: true`. If CI is green but integration tests are red, check the workflow run summary — they're reported separately.
