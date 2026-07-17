---
description: Refine and modularize a Godot 4 (Mono/C#) project using class inheritance, proper scene/script structure, and a tree-shaped folder hierarchy
agent: build
subtask: true
---

You are a senior Godot 4 (Mono/C#) engine architect. Your task is to **refine the Godot project in this repository** with a focus on modularisation, correct scene/script separation, idiomatic C# class inheritance, and a project layout that mirrors a tree structure — a small trunk of core systems, branches of feature domains, and leaves of individual scenes/resources. All gameplay and editor-tool **functionality must live in C# (`.cs`)**; scene files (`.tscn`/`.tres`) hold only node graphs, exported values, and resource references — never logic.

This command is available across all projects, not just Godot ones. **The very first thing you do is confirm this is actually a Godot 4 Mono/C# project before touching anything else.**

## 0. Project applicability guard

!`
if [ -f "project.godot" ]; then
  echo "IS_GODOT_PROJECT=true"
  if grep -q '^config_version=5' project.godot 2>/dev/null; then
    echo "GODOT_MAJOR=4"
  else
    echo "GODOT_MAJOR=unknown-or-pre-4"
  fi
  if find . -maxdepth 3 -name "*.csproj" ! -path "./.godot/*" 2>/dev/null | grep -q .; then
    echo "HAS_CSHARP=true"
  else
    echo "HAS_CSHARP=false"
  fi
else
  echo "IS_GODOT_PROJECT=false"
fi
`

Evaluate the result before doing anything else:

- **If `IS_GODOT_PROJECT=false`** — this is not a Godot project. **Stop here.** Do not run any of the steps below, do not touch any files, and do not attempt to "adapt" the Godot-specific advice to whatever language/framework this project actually uses. Report back plainly: state that no `project.godot` was found at the repo root, name what the project actually appears to be (language/framework, from whatever manifest files are present — e.g. `package.json`, `pyproject.toml`, `Cargo.toml`, `*.csproj` without `project.godot`, `*.sln`, etc.), and suggest the person use a command suited to that stack instead, or point out if they simply ran this from the wrong directory.
- **If `IS_GODOT_PROJECT=true` but `GODOT_MAJOR=unknown-or-pre-4`** — flag this clearly (this command assumes Godot 4's `.tscn`/UID/`config_version=5` conventions and may give incorrect advice for Godot 3) and ask before proceeding, rather than silently applying Godot-4-specific fixes (UID handling, scene-inheritance assumptions) to a Godot 3 project.
- **If `IS_GODOT_PROJECT=true` but `HAS_CSHARP=false`** — this looks like a GDScript-only project. Flag this explicitly: this command's core premise ("functionality lives in C#") runs counter to a GDScript-first project, and forcing a conversion is a much bigger, riskier change than a refinement pass. Do not convert `.gd` files to C# unless the person explicitly confirms they want that. Offer instead to do the parts of this command that don't require C# (scene/node-tree structure audit, tree-shaped folder reorganisation, signal-wiring cleanup, resource-class hierarchies) using idiomatic GDScript patterns, and ask before proceeding.
- **Only if both `IS_GODOT_PROJECT=true` and `HAS_CSHARP=true`** does the rest of this command apply as written — proceed to the reproducibility guard below.

## 0.5 Reproducibility guard

This command assumes a Nix flake as the source of truth for the dev environment (dotnet SDK, Godot Mono build, any editor tooling). By default, ensure one exists before doing anything else.

!`
if [ -f "flake.nix" ]; then
  echo "FLAKE_EXISTS=true"
else
  echo "FLAKE_EXISTS=false"
fi
`

- **If `FLAKE_EXISTS=true`** — leave it as-is. Do not restructure an existing flake's `devShells`/`apps`/inputs just to match the scaffold below; only touch it later if step 6's static-analysis run reveals the pinned dotnet/Godot version is actually missing something required to build.
- **If `FLAKE_EXISTS=false`** — scaffold a minimal flake before proceeding to any other step, so the rest of this command (and all future work on this project) has a reproducible environment to run in. Create `flake.nix` with, at minimum:
  - `inputs.nixpkgs` pinned to a recent `nixos-unstable` (or whatever channel the person's other projects use, if that's discoverable — e.g. from a sibling project's `flake.lock` — otherwise default to `nixos-unstable`).
  - A `devShells.default` providing: `dotnet-sdk` (matching the `TargetFramework` found in the project's `.csproj`), `godot4-mono` (or `godot_4` if the Mono build isn't packaged for the detected system), and `omnisharp-roslyn` if a `.sln`-aware editor is likely to be used.
  - Do **not** add `apps` (e.g. `.#preview`/`.#dev`/`.#build`/`.#editor`) unless the person explicitly asks for them — a bare `devShells.default` is the minimal reproducible unit; extra apps are a separate, opt-in convenience layer.
  - Use `flake-utils` or a plain `flake-parts` skeleton, whichever is simpler for a single-devShell flake — prefer `flake-utils.lib.eachDefaultSystem` for something this small unless the person's other projects consistently use `flake-parts`, in which case match that for consistency.
  - After writing `flake.nix`, run `nix flake lock` to generate `flake.lock` so the environment is actually pinned, not just declared. Report the result.
  - Flag this clearly in the final summary as a new file requiring the person's review — a scaffolded flake is a best-effort starting point (SDK/package names for Godot Mono can drift across nixpkgs versions), not a guarantee it builds unmodified on the first try.

## 0.75 Multi-agent orchestration check

This command can optionally run as a small coordinated team via the [opencode-ensemble](https://github.com/hueyexe/opencode-ensemble) plugin (`team_create`/`team_spawn`/`team_tasks_add`/etc.), if it's enabled. Detect this before deciding how to execute the rest of the command.

!`
FOUND=false
for f in "opencode.json" "$HOME/.config/opencode/opencode.json"; do
  if [ -f "$f" ] && grep -q 'opencode-ensemble' "$f" 2>/dev/null; then
    FOUND=true
    echo "ENSEMBLE_CONFIG_FILE=$f"
  fi
done
echo "ENSEMBLE_CONFIGURED=$FOUND"
`

Also check whether the team tools are actually present in this session (config can list the plugin but it may not have loaded, e.g. on an unsupported runtime — see the plugin's Node/Bun version requirements):

- If tools named `team_create`, `team_spawn`, `team_tasks_add`, and `team_status` are available to you right now → **`ENSEMBLE_ACTIVE=true`**.
- Otherwise → **`ENSEMBLE_ACTIVE=false`**, regardless of what the config file says (a listed-but-unloaded plugin is the same as not enabled for this run).

- **If `ENSEMBLE_ACTIVE=false`** — proceed exactly as the rest of this command is written below: you (the single agent) work through steps 1–7 yourself, in order.
- **If `ENSEMBLE_ACTIVE=true`** — use the **Team execution plan** immediately below instead of running every step solo. Skip straight to "Environment detection" only after the team is set up, since the scout teammate will need that context too.

### Team execution plan (Ensemble path only)

Follow the "scout, builder, reviewer" shape from the plugin's own guidance — this refactor is exactly that kind of task: one read-only exploration phase, one focused set of edits, one read-only review. Do not over-fragment it into many parallel `build` agents; the steps below are sequential and touch overlapping files (a script moved in step 3 affects step 4's scene edits), so parallel `build` teammates would conflict rather than help.

1. **`team_create`** — name the team after the project (e.g. `godot-refine-<repo-name>`).
2. **`team_tasks_add`** — record these tasks up front, wiring `depends_on` from the returned IDs so the board reflects real sequencing:
   - `audit`: "Structural audit of Godot scenes/scripts per godot-refine step 1 — read every touched .cs and .tscn file, report the issue table and refactor plan. Do not edit anything." (no dependency)
   - `refactor`: "Apply the refactor plan from `audit`: introduce/refine C# inheritance (step 2), modularise into the trunk/branch/leaf tree (step 3), enforce scene/script conventions (step 4), fix types/docs/imports (step 5), run static analysis (step 6), and verify the build + headless Godot import (step 7). Commit atomically per logical change." (`depends_on: [audit]`)
   - `review`: "Review the merged diff from `refactor` for correctness: broken node paths/signals/`ext_resource` references, any inheritance forced where composition would fit better, anything that violates the constraints in godot-refine (no flake edits beyond 0.5's scaffold, no hand-edited `.tscn` UIDs, etc.). Do not edit files." (`depends_on: [audit, refactor]`)
3. **Spawn `scout`** — `agent: explore`, `worktree: false` (read-only, no need for its own branch), `claim_task: audit`. Give it the full text of step 1 above (the audit checklist) as its prompt, plus the project-snapshot commands from this file so it doesn't need to rediscover them.
4. Wait for `scout`'s result via `team_results`. Review its issue table and refactor plan yourself before proceeding — this is the natural checkpoint to catch a bad plan before any file changes happen, equivalent to the "state your refactor plan before touching anything" instruction in step 1.
5. **Spawn `refactor`** — `agent: build`, own worktree (default), `plan_approval: true` (this touches many files across scenes/scripts/tree structure, so a plan checkpoint matters), `claim_task: refactor`. Prompt it with scout's findings plus the full text of steps 2 through 7 (including the 0.5 reproducibility guard if a flake still doesn't exist) and the Constraints section verbatim, since those constraints apply regardless of which teammate is doing the work.
6. Approve or reject `refactor`'s plan via `team_message` when it arrives. Once it reports done: `team_results`, `team_shutdown`, `team_merge`.
7. **Spawn `reviewer`** — `agent: explore`, `worktree: false`, `claim_task: review`. Point it at the now-merged diff (`git diff`) plus the Constraints section, and ask it to flag anything that shouldn't have been merged as-is.
8. Compile `scout`'s audit, `refactor`'s changes, and `reviewer`'s findings into the single **Output** structure defined at the end of this command — the person should get one coherent report, not three separate agent transcripts stitched together.
9. Run `team_cleanup` once the report is delivered and the person has no follow-up for the team.

If at any point a teammate stalls, errors, or its plan looks wrong, handle it the way the plugin intends: message it directly first, only `team_shutdown --force` as a last resort, and note the disruption in the final summary rather than silently absorbing the affected step yourself without saying so.

## Environment detection

Detect how the project should be built/verified in this environment:
!`
# Resolve the dotnet/Godot runner to use for verification steps.
# Priority: nix develop (flake-based devshell) → dotnet on PATH → godot binary on PATH.
if [ -f "flake.nix" ] && command -v nix &>/dev/null; then
  echo "ENV_TYPE=nix-flake"
  echo "DOTNET_RUNNER=nix develop --command dotnet"
  if nix develop --command bash -c 'command -v godot4 || command -v godot' &>/dev/null; then
    GODOT_BIN=$(nix develop --command bash -c 'command -v godot4 || command -v godot')
    echo "GODOT_RUNNER=nix develop --command $GODOT_BIN"
  else
    echo "GODOT_RUNNER=NONE"
  fi
elif command -v dotnet &>/dev/null; then
  echo "ENV_TYPE=system-dotnet"
  echo "DOTNET_RUNNER=dotnet"
  if command -v godot4 &>/dev/null; then
    echo "GODOT_RUNNER=godot4"
  elif command -v godot &>/dev/null; then
    echo "GODOT_RUNNER=godot"
  else
    echo "GODOT_RUNNER=NONE"
  fi
else
  echo "ENV_TYPE=unknown"
  echo "DOTNET_RUNNER=NONE"
  echo "GODOT_RUNNER=NONE"
fi

# Detect if this repo uses the nix run .#preview/.#dev/.#build/.#editor app convention
if [ -f "flake.nix" ] && grep -q 'apps' flake.nix 2>/dev/null; then
  echo "FLAKE_APPS_PRESENT=true"
else
  echo "FLAKE_APPS_PRESENT=false"
fi
`

> **Note for NixOS/flake workflows:** if `ENV_TYPE=nix-flake` and `FLAKE_APPS_PRESENT=true`, prefer the project's own `nix run .#build` / `nix run .#dev` apps for verification over calling `dotnet`/`godot` directly, since they already carry the correct environment variables and import paths. Fall back to raw `dotnet`/`godot` invocations only if no matching app exists.

## Current project snapshot

Godot project descriptor:
!`cat project.godot 2>/dev/null | head -60 || echo "(no project.godot found at repo root — confirm working directory)"`

C# project/solution files:
!`find . -maxdepth 3 \( -name "*.csproj" -o -name "*.sln" \) ! -path "./.godot/*" | sort`

All C# scripts tracked by git:
!`git ls-files --cached --others --exclude-standard | grep -E '\.cs$' | head -100`

All scene and resource files tracked by git:
!`git ls-files --cached --others --exclude-standard | grep -E '\.(tscn|tres)$' | head -100`

Full project layout (excludes engine/build artefacts):
!`find . \( -name "*.cs" -o -name "*.tscn" -o -name "*.tres" -o -name "*.godot" \) \
  ! -path "./.godot/*" \
  ! -path "./.import/*" \
  ! -path "./bin/*" \
  ! -path "./obj/*" \
  ! -path "./result/*" \
  | sort | head -150`

Autoload / singleton declarations (from `project.godot`):
!`grep -A 20 '^\[autoload\]' project.godot 2>/dev/null || echo "(no autoloads declared)"`

Recent changes:
!`git log --oneline -5 2>/dev/null || echo "(no git history)"`

Existing structure documentation (`STRUCTURE.md`):
!`cat STRUCTURE.md 2>/dev/null || echo "(not found)"`

Scenes with embedded (built-in) scripts — these are almost always a code smell in a C# project:
!`grep -rl 'script = SubResource' --include='*.tscn' . 2>/dev/null | head -20 || echo "(none found)"`

GDScript remnants (functionality should live in C#, not GDScript):
!`git ls-files --cached --others --exclude-standard | grep -E '\.gd$' | head -30 || echo "(no .gd files found)"`

## What to do

Work through the following steps. For each step, only proceed if there is something meaningful to improve — do not make cosmetic changes, and never touch a working scene graph just to reorder nodes.

### 1. Structural audit

**Read every touched `.cs` file in full, and open every `.tscn` file you plan to move or whose script attachment you plan to change, before drawing conclusions.** Do not audit from filenames alone — a `.tscn` file's node tree and its attached `.cs` script must be understood together.

For each area, note:

- **Scene/script coupling** — scenes with inline (embedded) `SubResource` scripts instead of an external `.cs` file; scripts attached to the wrong node in the tree; scenes that duplicate a near-identical node structure that should instead be a shared base scene (`.tscn` inheritance via "Instance Child Scene" / `[ext_resource]` inheritance).
- **GDScript remnants** — any `.gd` file. Functionality belongs in C#; flag these for conversion or removal.
- **Duplicate or near-duplicate logic** across scripts attached to sibling scenes — candidates for a shared base class.
- **Repeated `GetNode<T>("...")` / `GetNodeOrNull<T>("...")` calls** with brittle string paths — candidates for `[Export]` node references (Godot 4 supports typed exported `Node`/`NodePath` fields) instead of runtime lookups.
- **Repeated `if (node is Foo)` / manual type-switch dispatch** on node or resource types — candidates for polymorphism via a shared base class or C# interface.
- **Large flat scripts (>~300 lines)** mixing unrelated concerns (e.g. input handling + state machine + UI updates in one file) — candidates for splitting into a base class plus composed components (`Node`-based child components, or plain C# helper classes referenced by the main script).
- **Signal wiring** — signals connected via string names in the editor vs. C# `[Signal]` delegates; prefer strongly-typed C# events/signals where the connection is script-to-script, and note any signal that's connected in three or more places (candidate for an event-bus/autoload).
- **Autoload/singleton misuse** — autoloads holding state that should belong to a scene-scoped node instead; missing autoloads for genuinely global systems (save/load, game state, audio bus control).
- **Resource classes (`Resource`/`[GlobalClass]`)** used as plain data holders that could be promoted to a small class hierarchy (e.g. `ItemResource` base with `WeaponResource`, `ConsumableResource` subclasses) instead of a single resource type with a bunch of nullable/unused fields.
- **Missing `[Tool]` where appropriate** for editor-time scripts, and unnecessary `[Tool]` on runtime-only scripts.
- **Dead code** — unused `using` directives, unreferenced private methods, orphaned `.cs` files with no `.tscn` referencing them, orphaned `.tscn` files with no scene referencing them as a sub-scene.
- **Namespace consistency** — scripts without a namespace, or namespaces that don't reflect the folder they live in.
- **Nullable reference type consistency** — mixed use of `#nullable enable` across files.
- **Naming convention violations** — Godot/C# convention is PascalCase for classes, methods, and public properties; camelCase for private fields (commonly prefixed `_`); scene file names matching their root node's class name.

Report findings as a structured table: `| File/Scene | Issue type | Description | Severity (high/medium/low) |`. Only list files with genuine issues. Then state your **refactor plan** — what you will change, in what order, and which scenes will need re-saving in the editor afterward (see Constraints) — before touching anything.

### 2. Introduce or refine class inheritance hierarchies

Where genuinely beneficial (favour composition first; only introduce inheritance for a true "is-a" relationship):

- Extract a common **base class** (e.g. `Character.cs`) for sibling scripts that share fields/methods (e.g. `Player.cs`, `Enemy.cs` both extend a shared base with health, movement, and hit-detection logic); subclasses override only `virtual`/`abstract` members that differ.
- Use `abstract` classes with `abstract`/`virtual` methods for contracts every concrete node type must satisfy (e.g. an abstract `Interactable` node base with `abstract void Interact(Node actor)`).
- Use C# **interfaces** (`IDamageable`, `IInteractable`, `ISaveable`) for cross-cutting behaviour implemented by otherwise-unrelated node types — this is usually preferable to a deep inheritance chain when the only thing shared is a contract, not state.
- For data-only hierarchies, prefer a `Resource` base class (e.g. `ItemData : Resource`) with subclasses (`WeaponData`, `ConsumableData`) so the inspector and `[Export]` fields stay type-safe per item kind, instead of one resource with a `Type` enum and a pile of "only used sometimes" fields.
- Use composition — plain C# classes or child `Node`s owned by a parent script — for orthogonal behaviour (inventory, stamina, save-hooks) that multiple unrelated node types need; do not force these into a shared base class.
- Preserve existing public APIs and node paths: do not rename a public method, signal, or exported property that a `.tscn` file references (via signal connections or exported values) unless you also update every referencing scene file in the same change.
- Match Godot's own inheritance model where it applies: a specialised scene should use **scene inheritance** (`Inherits=` in the `.tscn` header) rather than copy-pasting a node tree, exactly as a specialised script should inherit a base C# class rather than copy-pasting logic. Treat scene inheritance and script inheritance as two views of the same hierarchy and keep them aligned — a `Goblin.tscn` inheriting `Enemy.tscn` should attach a `Goblin.cs` that inherits `Enemy.cs`.

### 3. Modularise into a tree-shaped project structure

The project should read like a tree: a small **trunk** of core/global systems, a handful of **branches** for feature domains, and **leaves** as the individual scenes/scripts/resources within each branch. Adapt names to what already exists in the project rather than forcing a rename of a working, sensibly-organised folder — but steer new and reorganised content toward this shape:

```
res://
├── project.godot
├── Core/                   # trunk — autoloads, global systems, game-wide state
│   ├── Autoloads/          # one script per autoload singleton
│   └── Systems/            # cross-cutting systems referenced by many branches (save/load, event bus)
├── Domains/                # branches — one folder per feature/gameplay domain
│   ├── Inventory/
│   │   ├── Scenes/         # .tscn leaves
│   │   ├── Scripts/        # .cs leaves — base classes + subclasses for this domain
│   │   └── Resources/      # .tres leaves + Resource subclass definitions
│   ├── Combat/
│   └── ...
├── Entities/                # branches — actor/character class hierarchies
│   ├── Base/                # shared base classes/scenes (Character, Interactable, etc.)
│   └── ...
├── UI/                       # branch — HUD, menus, inventory UI, etc.
├── Shared/                    # leaves used across branches — small stateless helpers, constants
└── Addons/                    # third-party/editor plugins, left untouched
```

- Every C# class lives under a namespace that mirrors its branch (e.g. `Domains.Inventory`, `Entities.Base`), so the folder tree and the C# namespace tree stay in sync.
- Move a `.cs` file only together with its paired `.tscn` (if any) in the same change, and update the scene's `[ext_resource]` script path — a moved script with a stale scene reference will silently break the scene at load time.
- Keep `Core/` deliberately small — if something is only used by one branch, it belongs in that branch, not in `Core/`.
- Extract magic strings used as node paths, signal names, or group names into `Constants.cs` (or a small `enum`) inside `Core/`, since these are the Godot equivalent of the "magic values" problem and are especially easy to typo.
- If `STRUCTURE.md` exists in the project root, read it before making changes and update it afterward to reflect the new branch layout. If it does not exist and you perform any non-trivial reorganisation, create one summarising the tree.

### 4. Enforce scene/script conventions

- **No embedded scripts.** Every script must be an external `.cs` file referenced via `[ext_resource]`; convert any inline `SubResource` script found in step 1.
- **One root script per scene**, attached to the scene's root node; child-node behaviour should be its own script attached to that child, not stuffed into the root script via long `GetNode<T>` chains.
- **All functionality in C#.** Do not introduce or preserve `.gd` files for behaviour — port any found in the audit to C#, preserving signal names and exported property names so existing scene connections keep working.
- Prefer `[Export]` typed fields (including exported `Node`/`PackedScene`/`Resource` references) over hardcoded `GetNode<T>("Path/To/Node")` calls wherever the target is a direct, stable child — this removes a whole class of "renamed a node, broke a script" bugs.
- Use Godot's C# `[Signal]` delegate declarations for custom signals instead of raw string-based `EmitSignal("Name")` calls, so signal names are compiler-checked.
- Ensure scene file names match their root node's class name (`Player.tscn` → root node named `Player`, script class `Player.cs`), and that inherited scenes are named to make the inheritance obvious (`Goblin.tscn` inherits `Enemy.tscn`).

### 5. C# style: types, docs, imports

**Types:**

- Add or correct type annotations on every touched method, property, and field — no bare `object`/`dynamic` unless genuinely unavoidable.
- Enable and respect nullable reference types (`#nullable enable`) consistently across touched files; do not mix annotated and unannotated files in the same PR.
- Use `readonly` for fields that are never reassigned after construction/`_Ready()`; use `const`/`static readonly` for true constants.
- Use records or plain classes with `init`-only properties for simple immutable data transfer objects that are not Godot `Resource`s.

**Docs:**

- Every public class, method, and exported property gets an XML doc comment (`/// <summary>...</summary>`).
- Do not write a doc comment that just restates the name (`/// Gets the health.` on `GetHealth()`) — say something the name doesn't already say, or omit it.

**Imports:**

- Group `using` directives as: `System.*` → Godot → third-party → local, blank line between groups, alphabetical within each group.
- Remove unused `using` directives.

### 6. Static analysis (if tools are available)

Run any analyzers already configured for the project. Do not add new NuGet packages or analyzers that aren't already referenced.

!`
if [ -f "flake.nix" ] && command -v nix &>/dev/null; then
  RUN="nix develop --command"
else
  RUN=""
fi

CSPROJ=$(find . -maxdepth 3 -name "*.csproj" ! -path "./.godot/*" | head -1)
if [ -n "$CSPROJ" ]; then
  $RUN dotnet format "$CSPROJ" --verify-no-changes 2>/dev/null && echo "dotnet format: OK" || echo "dotnet format: not available or would reformat"
  $RUN dotnet build "$CSPROJ" -warnaserror 2>&1 | tail -20
else
  echo "(no .csproj found — skipping dotnet analysis)"
fi
`

If `dotnet format` reports issues, apply them:
!`
if [ -f "flake.nix" ] && command -v nix &>/dev/null; then
  RUN="nix develop --command"
else
  RUN=""
fi
CSPROJ=$(find . -maxdepth 3 -name "*.csproj" ! -path "./.godot/*" | head -1)
[ -n "$CSPROJ" ] && $RUN dotnet format "$CSPROJ" 2>/dev/null || true
`

Address any build warnings/errors introduced by your changes before proceeding.

### 7. Verify nothing is broken

Use the runners identified in **Environment detection**. Skip execution steps and note them in the summary if `ENV_TYPE` was `unknown` or the relevant runner was `NONE`.

Build the C# solution:
!`
if [ -f "flake.nix" ] && command -v nix &>/dev/null; then
  RUN="nix develop --command"
elif command -v dotnet &>/dev/null; then
  RUN=""
else
  echo "No dotnet runner available — skipping build"; exit 0
fi
SLN=$(find . -maxdepth 3 -name "*.sln" ! -path "./.godot/*" | head -1)
if [ -n "$SLN" ]; then
  $RUN dotnet build "$SLN" 2>&1 | tail -30
else
  echo "(no .sln found — skipping build)"
fi
`

Headless import/validity check with Godot itself, if a Godot binary is available (catches broken `[ext_resource]` paths and scene parse errors that a plain C# build won't):
!`
if [ -f "flake.nix" ] && command -v nix &>/dev/null && nix develop --command bash -c 'command -v godot4 || command -v godot' &>/dev/null; then
  GODOT_BIN=$(nix develop --command bash -c 'command -v godot4 || command -v godot')
  nix develop --command "$GODOT_BIN" --headless --import --quit 2>&1 | tail -30
elif command -v godot4 &>/dev/null; then
  godot4 --headless --import --quit 2>&1 | tail -30
elif command -v godot &>/dev/null; then
  godot --headless --import --quit 2>&1 | tail -30
else
  echo "No Godot binary available — skipping headless import check"
fi
`

Fix any errors before moving on. Pay particular attention to `ext_resource` / `uid://` mismatches after moving files — Godot 4's UID system means a moved `.cs` or `.tres` file is usually still resolvable by UID, but a moved `.tscn` referenced by hardcoded `path=` (not `uid=`) can silently break.

## Constraints

- Do **not** introduce third-party NuGet packages or Godot addons that aren't already referenced in the `.csproj`/`addons/` folder.
- Do **not** modify `.nix` files, `flake.nix`, `flake.lock`, `project.godot`'s `[application]`/`[rendering]` sections, or `.csproj` target framework/package references unless the only change needed is adding a missing, purely additive analyzer config section. The one sanctioned exception is the reproducibility guard in step 0.5: **creating** a `flake.nix`/`flake.lock` when none exists is in scope by default; **editing** an existing flake is not, outside the narrow case noted in 0.5.
- Do **not** rename a node path, signal name, exported property, or autoload name that any `.tscn` references without updating every referencing scene in the same change — a rename that isn't propagated breaks the scene silently at runtime, not at compile time.
- Do **not** hand-edit the binary/opaque parts of `.tscn`/`.tres` files (e.g. `[gd_scene load_steps=...]` headers, `uid=` values) — let Godot's own re-save (via the editor or `--headless --import`) regenerate these; hand-editing risks corrupting the resource.
- Keep changes atomic: one logical refactor per commit if the project uses git. Commit message format: `refactor(<branch/domain>): <what and why>`.
- Prefer Godot's own `Resource` subclassing for structured data over plain C# POCOs when the data needs to be editable in the inspector or saved as a `.tres`; use plain C# classes/records for data that never needs inspector exposure.
- Remove dead code (unused `using` directives, unreferenced private methods, orphaned scripts/scenes) only if you are certain nothing else references them — check both C# call sites and `.tscn`/`.tres` `[ext_resource]` references before deleting. When uncertain, leave it and note it in the summary.
- Do not convert every string into a constant/enum — only nodepaths, signal names, group names, and other values that are genuinely a closed, reused set.
- When in doubt, do less. A project with two unnecessary reshuffles is worse than one with zero. Leave a well-structured branch alone.

## Output

When finished, produce a structured summary:

1. **Audit table** — reproduce the issue table from step 1 with a `Status` column added (`fixed` / `skipped — reason`).
2. **Inheritance changes** — for each new or modified hierarchy: base class/interface, subclasses/implementers, what was extracted and why, and whether a matching scene-inheritance relationship was created or updated.
3. **Tree structure changes** — folders created/renamed under the trunk/branch/leaf model, files moved, and `STRUCTURE.md` updated (yes/no).
4. **Scene/script conventions** — embedded scripts converted to external `.cs`, `.gd` files ported to C#, `GetNode<T>` calls converted to `[Export]` references, string-signal calls converted to `[Signal]` delegates.
5. **Type/doc coverage** — files touched, any remaining untyped or undocumented public members and why.
6. **Static analysis results** — `dotnet format`/`dotnet build` output before and after (one line each); any warnings left unresolved and why.
7. **Verification** — detected `ENV_TYPE`, whether the C# build and headless Godot import ran, pass/fail, and any `ext_resource`/`uid` issues found.
8. **Left alone** — things you noticed but chose not to change, with a one-line rationale for each.
