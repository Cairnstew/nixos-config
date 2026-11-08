---
name: jupyter-zed
description: Jupyter notebooks in Zed on a uv-managed venv — kernelspec wiring, LD_LIBRARY_PATH, and the "no kernel" failure modes
---

## What I do

Keep a notebook project's kernel, venv and Zed settings in agreement, and diagnose
the cases where Zed shows *no kernel* or a cell dies on import.

## Project Structure

```
.
├── flake.nix                 # dev shell: python312, uv, ruff, basedpyright, zed-editor
├── pyproject.toml            # [project].name IS the kernelspec name
├── .zed/settings.json        # jupyter.kernel_selections.python must match it
├── tools/install_kernel.py   # writes ~/.local/share/jupyter/kernels/<name>/kernel.json
├── notebooks/example.ipynb   # asserts sys.executable is the venv
└── src/my_project/           # importable package
```

## The invariant

Three places carry one name, and all three must agree:

1. `pyproject.toml` → `[project].name`
2. `.zed/settings.json` → `jupyter.kernel_selections.python`
3. `~/.local/share/jupyter/kernels/<name>/kernel.json` (generated)

## Common Tasks

### Confirm the kernel Zed will use

```bash
jupyter kernelspec list
cat ~/.local/share/jupyter/kernels/<name>/kernel.json   # argv must be .venv/bin/python
```

The `argv` is an **absolute path**, deliberately. A bare `python` resolves through
`PATH`, so the cell's interpreter depends on how the editor was launched.

### Re-register after `uv sync`

`uv sync` may rebuild `.venv`, leaving a stale interpreter path in the spec:

```bash
.venv/bin/python tools/install_kernel.py
```

The flake's `shellHook` already does this on every entry; run it by hand only if you
created the venv outside the shell.

### Add a dependency

```bash
uv add scipy        # runtime
uv add --dev polars # dev group
```

Then re-enter the shell so the kernelspec and `PATH` are refreshed.

## Failure modes

**No kernel in Zed.** In order: (1) spec missing → run `install_kernel.py`;
(2) name mismatch between `pyproject.toml` and `.zed/settings.json`;
(3) direnv never ran (`.envrc` is `use flake`, Zed setting is
`load_direnv: "direct"`, and `direnv allow` is per-directory);
(4) worktree untrusted — project settings are ignored until it is.

**`libz.so.1: cannot open shared object file` on `import pandas`.** PyPI wheels link
by soname and NixOS has no `/lib`. The flake's `LD_LIBRARY_PATH` (zlib +
`stdenv.cc.cc.lib`) fixes it *inside the dev shell only*; a kernel started from a
different environment still fails.

**`zeditor .` opens nothing.** Zed hands CLI requests to a running instance over
`~/.local/share/zed/zed-stable.sock`. If that instance has no Wayland surface it
swallows them. Kill it, `rm -f ~/.local/share/zed/zed-stable.sock`, relaunch from a
shell inside the graphical session.

**`ruff` / `basedpyright` from the venv do not start.** Their PyPI wheels are
dynamically linked and fail on NixOS. Use the nixpkgs binaries the dev shell
provides; do not `uv add ruff`.

## Tips

1. Do not add `jupyter`/`ipykernel` to the flake's `packages` — the venv owns them,
   and `.venv/bin` is prepended to `PATH` so there is exactly one `jupyter`.
2. `ipykernel` is the package Zed needs; `jupyterlab` is only for the browser UI.
3. The venv interpreter is uv's managed CPython pinned by `.python-version`, not the
   shell's `python312` — a venv built from a store path breaks after `nix gc`. Bump
   it with `rm -rf .venv` after editing `.python-version`.
4. A notebook cell asserting `".venv" in sys.executable` catches a mis-selected
   kernel far faster than reading the kernel picker.
