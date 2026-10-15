# Houdini Project Template

A Houdini project scaffold whose flake provides a development shell and
run-apps wired to the **Houdini already installed on your system**.

## Why the system Houdini

SideFX Houdini is proprietary: it cannot be fetched by Nix and is not in
nixpkgs. This template therefore does **not** depend on a `houdini` package.
It uses the `houdini`/`hython` wrappers that nixos-config's
`my.programs.houdini` module installs into `/run/current-system/sw/bin`
(a `houdini-nix` build plus the FHS launcher, Vulkan/Qt/QML fix-ups, and the
licensing setup).

`nix develop` and `nix run` inherit the ambient `PATH`, so the system wrappers
are found by name — and they must be used by name. Never add `$HFS/bin` to
`PATH`: that bypasses the module's launcher and Houdini crashes on startup.

## Requirements

- Houdini installed system-wide:

  ```nix
  my.programs.houdini.enable = true;
  ```

- A valid SideFX license (Apprentice/NC or full), configured by the module.
- `nix` with flakes enabled (or `direnv`).

## Usage

```bash
# Optionally scaffold a fresh project from the nixos-config flake:
nix flake init -t ~/nixos-config#houdini

# Enter the dev shell (direnv: `direnv allow` once):
nix develop

# Inside the shell, `hython` and `houdini` come from the system, and the
# project environment below is already active.
hython scripts/example.py
houdini hip/                                    # open the GUI here
```

Without entering a shell:

```bash
nix run .#houdini            # launch the GUI with the project environment
nix run .#hython -- scripts/example.py
nix run .#basedpyright       # type-check scripts/ (what Zed's LSP runs)
nix run .#pyright            # same, with pyright instead of basedpyright
```

## Project environment

On shell entry the flake exports:

| Variable | Value | Purpose |
|----------|-------|---------|
| `JOB` | project root | Houdini's `$JOB` project directory |
| `HIP` | `<project>/hip` | directory Houdini opens `.hip` files from |
| `HOUDINI_PATH` | `<project>/houdini:&` | loads `./houdini` as a Houdini package |

`&` expands to Houdini's default search path, so `./houdini` is *prepended*
rather than replacing the built-in paths.

## MCP server (AI scene control)

The project ships an [MCP](https://modelcontextprotocol.io) server
([oculairmedia/houdini-mcp](https://github.com/oculairmedia/houdini-mcp),
43 tools) that lets an AI assistant inspect and drive the **running** Houdini
session: read scene/node/parameter state, create and wire nodes, execute Python
and HScript, render the viewport, capture pane screenshots, and fetch SideFX
docs. It talks to Houdini over `hrpyc` (RPyC), so nothing is baked into the
`.hip` file and the server can be restarted independently of the session.

OpenCode picks it up automatically from `.opencode/opencode.json` (stdio
transport, `localhost:18811`). Houdini itself must expose the RPC server first
— in Houdini's **Python Shell**:

```python
import hrpyc
hrpyc.start_server(port=18811)
```

Or add those two lines to `123.py` to start it with every scene.

The server also runs on its own:

```bash
nix run .#houdini-mcp                      # HTTP on :3055 (health: /health)
MCP_TRANSPORT=stdio nix run .#houdini-mcp # what opencode uses
```

> **Why the command is an absolute flake ref, and who writes it:** opencode
> spawns MCP servers from its **web daemon's cwd** — in practice often
> `~/nixos-config`, never the project — so a `.#houdini-mcp` ref dies there with
> `error: could not find a flake.nix file` and opencode only reports
> `server unavailable … status=failed`. The absolute path has to be known before
> the file is committed, which is impossible for a scaffolded project, so the
> **shell hook regenerates `.opencode/opencode.json` on every `nix develop`**
> (idempotently — it only rewrites when the path actually changed), exactly as
> it already regenerates `pyrightconfig.json`. Enter the shell once before
> expecting opencode to find the server.
>
> `/run/current-system/sw/bin/nix` is likewise spelled out absolutely rather
> than as bare `nix`: this service runs under systemd with a restricted `PATH`
> (ripgrep, git, coreutils … — no `nix`), where a bare `nix` fails with
> `env: 'nix': No such file or directory`, exit 127.
>
> **And the env block key is `"environment"`, not `"env"`.** This is the trap
> that cost the most time: opencode validates an MCP block against
> `McpLocalConfig` (`additionalProperties: false`) and **silently drops keys it
> does not recognise** — a `"env": {...}` block is discarded with no warning, so
> `MCP_TRANSPORT=stdio` never arrives and the server falls back to its default
> of **HTTP on :3055**. It binds a socket, never speaks JSON-RPC on stdio, and
> opencode kills it with `Operation timed out after 30000ms`, reported upstream
> only as `status=failed`. The valid keys are `type`, `command`, `cwd`,
> `environment`, `enabled`, `timeout` — `environment` is also the spelling the
> nixos-config `my.*` module uses, so the two files never diverge. If a server
> here ever stops working, check the transport first: `opencode mcp list`
> distinguishes the failure modes (`Operation timed out after 30000ms` = the
> child started but never spoke stdio; an immediate failure = the command could
> not run at all).

Configuration via environment variables: `HOUDINI_HOST` / `HOUDINI_PORT`
(default `localhost:18811`), `MCP_TRANSPORT` / `MCP_PORT` (default `http`/`3055`).
The tools only see the Houdini session, so `check_connection()` is the usual
first call — it reports whether `hrpyc` answered.

Two packaging notes: the upstream package is not in nixpkgs, so `flake.nix`
pins it to a commit; and `hrpyc` speaks **RPyC 5.x only** (the 6.x line changed
the protocol), so rpyc 5.3.1 is built from PyPI rather than taken from
`python3Packages.rpyc`.

## Editor setup (Zed, VS Code, Neovim, …)

> **First, once per machine: enter the shell, then restart the language server.**
>
> ```bash
> direnv allow          # or: nix develop
> ```
>
> The `.hou-libs`, `.hou-site` and `.stubs` symlinks do not exist in a fresh
> clone until the shell hook runs. An editor that was **already open** before
> that resolves `hou` against the raw SWIG source and reports stale errors
> (`Argument missing for parameter "self"`, `Attribute "set" is unknown`) —
> run `editor: restart language server` once and they disappear. Nothing else
> about the setup is affected.

`hou` is a compiled SWIG extension that exists only inside Houdini's own
interpreter. An editor that type-checks with a plain `python3` on `PATH`
therefore reports `Import "hou" could not be resolved` — the import is fine,
the *interpreter* is wrong.

Houdini *does* ship the real module as Python source, at
`$HFS/houdini/python3.13libs/hou.py` (124k lines of SWIG boilerplate), and a
type-checker can read that directly. But that source is typed with C pointers
— literally `def pwd() -> "HOM_Node *"` — so nothing resolves and every `hou`
call comes back `Unknown`. On its own it is not enough.

So the setup is **three parts, all symlinked in by the flake**:

| Piece | Purpose |
|-------|---------|
| `.hou-libs` | symlink to Houdini's `houdini/python3.*libs` — real source for `hou`, `toolutils`, `husd`, `hutil`, `viewerstate`, `houcppportion`, … |
| `.hou-site` | symlink to Houdini's `python/lib/python3.*/site-packages/pxr` — resolves `import pxr` (USD) |
| `.stubs` | symlink to the `types-houdini` stub package — hand-cleaned `.pyi` annotations for `hou`, plus a `__builtins__.pyi` |

`pyrightconfig.json` then reads:

```jsonc
"extraPaths": [".hou-libs", ".hou-site"],
"stubPath": ".stubs"
```

`pyright` / `basedpyright` prefer `stubPath` over `extraPaths` for a module
that has both, so `hou` resolves against the annotated stubs while
`toolutils` / `husd` / `hutil` / `viewerstate` fall through to Houdini's real
sources. (`hou-stubs/__init__.pyi` itself starts with
`from houcppportion import *`, so `.hou-libs` is still required.)

All three are **git-ignored and created by the flake** on every
`nix develop` and `nix run .#basedpyright`. They have to be resolved by glob
because both the content-addressed store path *and* the `python3.13libs`
component change when Houdini is upgraded; a hardcoded path would break
silently. If anything is ever wrong, `direnv reload` (or re-running either
command) repairs it.

`pythonVersion` is pinned to Houdini's bundled interpreter rather than
whatever `python3` happens to be on `PATH`. This matters more than it looks:
pyright honours `pythonVersion` for the *language level* but still resolves
imports through the first `python3` it finds, which on NixOS is usually
nixpkgs' (often a newer one than Houdini's). Left alone, that mixes a 3.13
language level with a 3.14 standard library. Because the value would drift on
upgrade, the flake rewrites it from the same glob it uses to create
`.hou-libs`, on every `nix develop` / `nix run .#basedpyright`. The committed
value is only the fallback for an editor opened before the shell hook has
run — check which one is active from the dev-shell banner:

```
  hou stubs: /nix/store/…-houdini-type-stubs
  python:    3.13 (Houdini's hython)
```

### Zed

Zed's Python extension runs **basedpyright**, which reads
`pyrightconfig.json` from the project root — so it picks all of the above up
with no Zed-specific configuration. `.zed/settings.json` only handles the
directory trust prompt and `direnv` loading.

With `load_direnv: "direct"` the dev shell goes on the environment Zed spawns
language servers with, and because `basedpyright` is a devShell package Zed
finds it there rather than downloading its own. Zed's log confirms it
(`found user-installed language server for basedpyright`, then `starting
language server process. binary path: "...-basedpyright-1.39.8/bin/..."`).
Nothing pins a store path, so the config is repo-portable; a fresh machine
simply gets whatever basedpyright its devShell resolves.

`.zed/tasks.json` adds — all of them resolve `hython` / `basedpyright` through
the same direnv environment:

| Task | Runs |
|------|------|
| `hython: run file` | `hython $ZED_FILE` |
| `basedpyright: check file` | `basedpyright $ZED_FILE` |
| `basedpyright: check project` | `basedpyright scripts` |
| `houdini: refresh editor symlinks` | `direnv reload` |

### The `hou.pwd()` trap (and how to type around it)

`hou.pwd()` and `hou.node()` return **`hou.Node`**, not `hou.SopNode`. Since
Houdini 20, `hou.Node` is an abstraction the network editor shares with APEX
nodes, and most node-specific methods (`parm`, `geometry`, …) moved to
`hou.OpNode`. So this reads as an error even though it works at runtime:

```python
geo = hou.pwd().geometry()   # error: "geometry" is not a known attribute of "Node"
```

Narrow it when you know what the node is:

```python
from typing import cast

node = cast(hou.SopNode, hou.pwd())
geo = node.geometry()        # Geometry | None
```

A plain annotation (`node: hou.SopNode = hou.pwd()`) does **not** work — it is
an unproven downcast and the type-checker is right to reject it.

Two related gotchas, both handled in `scripts/example.py`:

- `hou.node(path)` returns `Optional[hou.Node]` (the path may not exist), so it
  needs a `None` check first.
- `hou.OpNode.parm(path)` returns `Optional[hou.Parm]`, so `.set()` cannot be
  chained off it directly.

### Houdini version vs stubs version

`types-houdini` is pinned in `flake.nix`; its version number names the Houdini
install it was generated from, **not** the Houdini you have installed. The
installed Houdini here is **22.0.368** and the pinned stubs are **21.0.512** —
a full major version apart. Bump the pin when you want fresher coverage, with
`nix-prefetch-url <files.pythonhosted.org wheel URL>` and editing `hash`.

What that gap actually costs, measured by diffing the public API of
22.0.368's `hou.py` against the stubs:

- **22 public classes are missing from the stubs** — mostly the APEX rework
  (`UniNode`, `UniNodeConnection`, `UniNodeType`, `UniNodeTypeCategory`,
  `UniStickyNote`, `ApexUniGraphDebugger`) plus `Camera`, `CameraPrim`,
  `ChannelListPaneTab`, `CopCable`, `DetachedAttrib`, `OpenCLDevice`,
  `ViewerDragger2D`, `ViewerHandleDragger2D`, `ViewerStateDragger2D`.
- **228 public methods exist in 22 but not in the stubs**, concentrated in
  newer subsystems: `ImageLayer` (−31), `ChannelGraph` (−12, the retiming
  tools), `Geometry` (−12), `ParmTuple` (−15), `Parm` (−11), `Drawable2D`
  (−11), `NanoVDB` (−10), `Volume` (−14), `OpNode` (−9).
- **7 public module functions are missing**: `frameTolerance`,
  `timeTolerance`, `nodeTypeCategory` and four `uni*BySessionId` helpers.
- **Two classes in the stubs no longer exist in 22**: `ChannelEditorPane`
  (renamed) and `data`.

The sharpest edge is the **`hou.Node` / `hou.OpNode` split**: between 21 and 22
SideFX moved several methods between the two classes, so the stubs attribute
`copyNetworkBox`, `copyStickyNote` and `editableInputString` to `hou.Node`
where 22 has them on `hou.OpNode`, and `setParms` to `hou.OpNode` where 22 has
it elsewhere. A `Node`-typed value can therefore refuse a call that works at
runtime. `cast` to the concrete node type (see below) when that happens — it
is a stub-staleness artifact, never a real error.

None of this is patched here. cg-stubs is actively maintained but its Houdini
work is on 21.0; there is no 22.0 stub release or open PR for one.

### A note on `pxr`, and `types-usd`

`pxr` is linked as real source, not stubs: `pxr/__init__.py` is a one-line
`__all__` and every real API lives in compiled `_usd.so` / `_tf.so`. So
`import pxr` resolves, but attribute access on `pxr` types stays *partially
unknown* — module resolution only, no completion on `pxr.Usd.Stage` and
friends.

`types-usd` from the same cg-stubs project would give real USD types. It is
**not** included, because the gap is worse than `hou`'s: its latest release is
24.5.2, generated from **USD 24.05**, while Houdini 22.0.368 bundles
**USD 26.05** (`PXR_VERSION 2605`). Adding it would be the same
wheel-unzip pattern as `houdiniTypeStubs` and would need its own `.stubs`
entry, but two majors stale is a poor trade for a large dependency. Revisit if
you start writing substantial USD code.

### Why `typeCheckingMode` is `"basic"`, and one demoted rule

Even with the stubs, a large part of `hou` (and all of `pxr`) is declared via
`Incomplete` and `from ... import *`. Under `"strict"` that warns on
essentially every `hou` call, drowning out real problems; `"basic"` still
catches undefined names, wrong argument counts and bad attribute access.

`reportAttributeAccessIssue` is demoted to `"warning"` because Houdini's own
`__init__.py` files hide names that exist at runtime: `husd/__init__.py`
star-imports three modules and so hides `husd.Stage`; `hutil/__init__.py`'s
`__all__` has no `glob`; `pxr/__init__.py` never imports its submodules.
**Worth reading even though they are yellow**: the same rule is what catches a
genuine typo such as `node.parmx("radx")`, so an "unknown attribute" warning
deserves a glance — it is either one of the visibility cases above or a real
mistake, and the two are easy to tell apart.

### Optional: editing snippets inside Houdini (mxe)

Nothing above is needed to edit whole scripts. If you also want to edit the
code *embedded in* a Houdini scene — Python SOPs, wrangles, `hou.session`, HDA
sections, shelf tools — [mxe](https://github.com/peterprickarz/mxe) is a
Houdini package (Houdini 19.5+/sidefx-Labs era) that opens those in an external
editor through any editor's `edit` command and sends the saved file back into
Houdini via a file watcher. Configure `Edit → Preferences → MXE: Set Editor
(Python)` to `zed` and saving in Zed round-trips into the node.

It is a workflow convenience, not a type-checking one: it plays no part in
resolving `hou`, and the files it hands Zed are temporary scratch files
outside this project, so they are not covered by `pyrightconfig.json`. Its
docs only cover VS Code / PyCharm / Sublime Text, but Zed is "any editor" to
it as long as `zed <file>` opens and saves in place.

## Linting

`ruff` is provided for style outside Houdini's interpreter:

```bash
ruff check .
ruff format .
```

## Layout

```
.
├── flake.nix          # dev shell + `nix run` apps (system Houdini)
├── pyrightconfig.json # type-checking; resolves `hou` via .stubs/.hou-libs/.hou-site
├── .zed/              # Zed project settings + tasks
├── .opencode/         # opencode config — the houdini MCP server (stdio)
├── hip/               # scene files ($HIP) — *.hip, *.hiplc
├── houdini/           # a Houdini package, auto-loaded via HOUDINI_PATH
│   ├── otls/          #   digital assets (*.hda, *.otl)
│   ├── python/        #   startup/module Python (importable as `houdini.*`)
│   ├── scripts/       #   shelf/startup scripts (123.py, 456.py, ...)
│   ├── vex/           #   VEX includes (.vfl), included from wrangles
│   └── toolbar/       #   shelf definitions (.shelf)
└── scripts/           # standalone hython tools (run with `nix run .#hython`)
```

`.hou-libs`, `.hou-site` and `.stubs` are git-ignored: they are machine- and
Houdini-version-specific symlinks the flake rebuilds.

## Notes

- The template's `flake.lock` pins nixpkgs + flake-parts. Bump with
  `nix flake update`.
- Nothing in this project vendors Houdini; it stays a thin wrapper over the
  system install, so the project keeps working across Houdini upgrades.
