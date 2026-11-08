# my-project

Jupyter notebooks in **Zed**, on a Python environment that `uv` manages and the dev
shell wires up. `nix develop` gives you `python`, `uv`, `ruff`, `basedpyright` and
`zeditor`; `uv` owns the interpreter-level packages.

## Quickstart

```bash
direnv allow          # or: nix develop
zeditor .             # then open notebooks/example.ipynb
```

The first shell entry runs `uv sync` (network required) and registers a Jupyter
kernelspec named after `[project].name` in `pyproject.toml`.

```bash
jupyter kernelspec list     # confirm the spec exists
jupyter lab                 # same kernel, browser UI
uv add scipy                # add a runtime dep; re-enter the shell afterwards
```

## Renaming the project

Three things carry the name and must stay in agreement:

| Where | What |
|-------|------|
| `pyproject.toml` | `[project].name` — this **is** the kernelspec name |
| `.zed/settings.json` | `jupyter.kernel_selections.python` |
| `src/my_project/` | the importable package directory |

```bash
grep -rn "my-project\|my_project" --include='*.toml' --include='*.json' --include='*.nix' .
```

## How the kernel is wired

1. `flake.nix`'s `shellHook` creates `.venv` with `uv sync` on first entry.
2. It then runs `tools/install_kernel.py`, which writes
   `~/.local/share/jupyter/kernels/<name>/kernel.json` with `argv` naming
   `.venv/bin/python` **by absolute path**.
3. `.zed/settings.json` sets `jupyter.enabled` and selects that kernel for
   `python`.

Step 2 is idempotent and runs on every shell entry, so the spec always points at the
current venv — `uv sync` may rebuild `.venv` at any time, and a spec holding a stale
interpreter path fails only when you run a cell.

**Why not let the venv's own `python3` spec do the work?** Its `argv` is a bare
`python` resolved through `PATH`, so which interpreter runs a cell depends on how
the editor was launched. A notebook then imports a different package tree (or
none) than the one you are testing.

## Zed shows no kernel

Work through these in order:

1. `jupyter kernelspec list` shows the spec? If not, enter the shell once —
   `.venv/bin/python tools/install_kernel.py`. `uv sync` alone does not register
   it.
2. The name in `jupyter.kernel_selections.python` matches `[project].name`?
3. Did Zed run `.envrc`? The setting is `load_direnv: "direct"`, which needs
   `direnv` installed **and** `direnv allow` run once in this directory. Without
   it, launch Zed from inside `nix develop` instead.
4. Is the worktree trusted? Untrusted worktrees ignore project settings entirely;
   `session.trust_all_worktrees = true` in `.zed/settings.json` is what skips the
   prompt, and it only takes effect once the file itself is trusted.

## Gotchas

**`import pandas` fails with `libz.so.1: cannot open shared object file`.** PyPI
wheels link against libraries by soname and NixOS has no `/lib`. The flake exports
`LD_LIBRARY_PATH` with `zlib` and `libstdc++` for exactly this — keep that line if
you add numpy/pandas/matplotlib/scipy/pyarrow. It applies inside the dev shell only,
so a kernel launched from elsewhere will still fail.

**`zeditor .` prints nothing and no window appears.** Zed's GUI is a per-user
singleton: the CLI hands the request to a running instance through
`~/.local/share/zed/zed-stable.sock`. An instance started without
`WAYLAND_DISPLAY`/`DISPLAY` keeps the socket and swallows every open request.
`kill` that process, `rm -f ~/.local/share/zed/zed-stable.sock`, then relaunch
**from a shell inside the graphical session** (`setsid --fork zeditor .`).

**`ruff`/`basedpyright` from the venv refuse to run.** Their PyPI wheels are
dynamically linked and do not start on NixOS. The shell provides the nixpkgs
binaries instead — use those, and do not `uv add ruff`.

**The notebook kernel ignores the nixpkgs interpreter.** That is intended: the
kernel is `.venv/bin/python`, so `nixpkgs`' `python312` is the *builder* for the
venv, never its runtime. `python -V` inside the shell reports the venv's version.

## Layout

```
flake.nix                  dev shell: python312, uv, ruff, basedpyright, zeditor
pyproject.toml             deps + dev group (ipykernel, jupyterlab, pytest, ruff)
.python-version            pins the venv interpreter (uv-managed CPython 3.12)
.zed/settings.json         jupyter kernel selection, direnv, python formatting
tools/install_kernel.py    writes the kernelspec pinned to .venv/bin/python
notebooks/example.ipynb    sanity notebook (asserts the venv kernel, plots)
src/my_project/            importable package
```

## Interpreter choice

The venv's interpreter is **uv's managed CPython**, pinned by `.python-version`, not
the dev shell's `python312`. That is deliberate: a venv built from a `/nix/store`
python breaks as soon as that path is garbage-collected, while uv's download lives
in `~/.local/share/uv` and survives `nix gc`. `python312` in the shell is a fallback
interpreter `uv` can find, and the thing `.venv` is *not* built from.

Bump it by editing `.python-version`, then `rm -rf .venv` and re-enter the shell.

`pkgs.zed-editor` drags in a sizeable closure (~1 GB: nodejs, pipewire, bluez). If
Zed is already on the host — e.g. this repo's `my.programs.zed-editor` module —
delete that line from `flake.nix` and the shell becomes a few hundred MB.


## Further reading

- Zed notebook docs: <https://zed.dev/docs/notebooks>
- uv: <https://docs.astral.sh/uv/>
