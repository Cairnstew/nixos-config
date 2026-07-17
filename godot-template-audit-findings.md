# Godot Template Audit Findings

**Date:** 2026-07-03
**Host:** desktop (AMD)
**Laptop:** unreachable (offline 3d) — GPU test skipped

---

## Task 1: MCP Tool Audit (`godot-mcp`)

### Tool list (sourced from `src/index.ts` on GitHub)

All 14 tools classified by category and destructiveness:

| Tool Name | Category | Destructive? |
|---|---|---|
| `launch_editor` | mutates running editor state | No |
| `run_project` | mutates running editor state | Minor (kills prior running process) |
| `get_debug_output` | read-only | No |
| `stop_project` | mutates running editor state | Minor (kills running process) |
| `get_godot_version` | read-only | No |
| `list_projects` | read-only | No |
| `get_project_info` | read-only | No |
| `create_scene` | mutates project files | **Yes** — creates/overwrites .tscn files on disk |
| `add_node` | mutates project files | **Yes** — modifies scene file on disk |
| `load_sprite` | mutates project files | **Yes** — modifies scene file, replaces texture reference |
| `export_mesh_library` | mutates project files | **Yes** — creates/overwrites .res file |
| `save_scene` | mutates project files | **Yes** — overwrites scene in-place or creates variant |
| `get_uid` | read-only | No |
| `update_project_uids` | mutates project files | **Yes** — resaves/re-writes all resource files in the project |

**Breakdown:** 6 read-only, 6 mutate project files, 2 mutate running editor state, 1 mixed (run_project kills prior process)

### Currently auto-approved (raw from `opencode.json`):

```json
"autoApprove": [
    "launch_editor", "run_project", "get_debug_output", "stop_project",
    "get_godot_version", "list_projects", "get_project_info",
    "create_scene", "add_node", "load_sprite", "export_mesh_library",
    "save_scene", "get_uid", "update_project_uids"
]
```

**All 14 tools** are currently auto-approved.

### Verdict: **GAP FOUND**
7 destructive tools (create_scene, add_node, load_sprite, export_mesh_library, save_scene, update_project_uids, run_project) are auto-approved — candidates for removal from autoApprove. `update_project_uids` is especially broad (resaves ALL resources in the project).

---

## Task 2: godot-mcp Reproducibility

### Version

```text
$ nix shell nixpkgs#nodejs_22 --command bash -c 'npm view @coding-solo/godot-mcp version'
0.1.1

$ nix shell nixpkgs#nodejs_22 --command bash -c 'npm view @coding-solo/godot-mcp versions --json'
["0.1.1"]
```

Only one version ever published — `0.1.1` (2026-02-03). No lockfile shipped with the template.

### npm availability

```text
$ ls /nix/store/...-nodejs-22.22.3/bin/ | grep -E 'npm|npx'
npm
npx
```

`nodejs_22` ships `npm` and `npx` in its `bin/` directory — the `npx @coding-solo/godot-mcp` command in `opencode.json` will work when `nodejs` is on PATH (which it is, since the dev shell includes it).

### Pinning feasibility

```text
$ npm view @coding-solo/godot-mcp --json  | jq '.dist-tags, .version, .dependencies'
"latest": "0.1.1"
"version": "0.1.1"
"dependencies": {
  "@modelcontextprotocol/sdk": "0.6.0",
  "axios": "^1.7.9",
  "fs-extra": "^11.2.0"
}
```

Possible approaches:
1. **buildNpmPackage** in the flake — fetch source tarball from npm/GitHub, pin with SRI hash
2. **vendored lockfile** — `npm install --package-lock-only` and commit `package-lock.json` to the template
3. **npx with explicit version** — `npx -y @coding-solo/godot-mcp@0.1.1`

Currently the template does **none** of these — it relies on live `npx` fetching latest on every cold start.

### Verdict: **GAP FOUND**
No pinned version, no lockfile. The template downloads `@coding-solo/godot-mcp` live from npm on every first run. Easy to pin (single existing version 0.1.1). The `buildNpmPackage` approach would give full Nix reproducibility.

---

## Task 3: GPU / Editor Launch on Both Hosts

### AMD Desktop (this host)

```text
$ hostname
desktop

$ which godot
/nix/var/nix/profiles/system/sw/bin/godot

$ godot --headless --version
4.6.3.stable.nixpkgs.35e80b3a8

$ godot --headless --version --verbose
4.6.3.stable.nixpkgs.35e80b3a8

$ godot --headless --dump-extension-api 2>&1 | head -5
Dumping Extension API
Godot Engine v4.6.3.stable.nixpkgs.35e80b3a8 - https://godotengine.org
```

No Mesa/Vulkan loader errors. Clean output.

### Intel Laptop

```text
$ ssh laptop 'godot --headless --version 2>&1'
SSH_FAILED: laptop unreachable (offline 3d)
```

**Could not test on laptop** — laptop is offline (last seen 3d ago via Tailscale). Laptop GPU is Intel integrated (kvm-intel).

### Verdict: **NEEDS DECISION**
AMD desktop is clean. Laptop test blocked by host being offline. Cannot confirm Intel GPU compatibility.

---

## Task 4: Export Template Gap

### What `nix flake check` exercises

```text
$ nix flake check --no-build 2>&1 | grep -i 'godot\|export\|template'
$ echo "(no output)"
```

The flake currently produces **no checks** related to Godot export. The template's `flake.nix` only defines `devShells.default` — no `checks` attribute, no export build step, no test derivation.

### Export attempt

```text
$ mkdir -p /tmp/godot-export-test/default
$ cat > /tmp/godot-export-test/project.godot << 'EOF'
[application]
config/name="Export Test"
run/main_scene="res://default/main.tscn"
EOF
$ cat > /tmp/godot-export-test/default/main.tscn << 'EOF'
[gd_scene load_steps=2 format=3 uid="uid://test123"]
[sub_resource type="Camera2D" id=1]
[node name="Root" type="Node2D"]
EOF
$ cd /tmp/godot-export-test && godot --headless --export-release "Linux/X11" /tmp/test-export 2>&1
...
ERROR: This project doesn't have an `export_presets.cfg` file at its root.
Create an export preset from the "Project > Export" dialog and try again.
   at: _fs_changed (editor/editor_node.cpp:1348)
```

Export fails because `export_presets.cfg` is missing — expected, this must be generated by the Godot editor.

### What export templates are available in nixpkgs

```text
$ nix eval nixpkgs#godot-export-templates-bin.meta.description
"Free and Open Source 2D and 3D game engine"
$ nix eval nixpkgs#godot-export-templates-bin.version
"4.6.3-stable"
```

`godot-export-templates-bin` exists in nixpkgs at version 4.6.3-stable (same as the engine).

### What would be needed for reproducible export

1. An `export_presets.cfg` in the template (with platform presets like Linux/X11, Windows Desktop, etc.)
2. `godot-export-templates-bin` added to the dev shell packages
3. Optionally: a flake `checks` attribute that runs `godot --headless --export-release` as a CI step

### Verdict: **GAP FOUND**
No export_presets.cfg. No export-templates-bin in dev shell. No CI check for export. Three separate gaps.

---

## Task 5: Scene File Sanity

### Files in `default/`

```text
$ ls -la templates/godot/default/
total 12
drwxr-xr-x 2 seanc users 4096 Jul  3 17:59 .
drwxr-xr-x 2 seanc users 4096 Jul  3 17:59 ..
-rw-r--r-- 1 seanc users  336 Jul  3 17:59 default_env.tres

$ find templates/godot -name '*.tscn' -o -name '*.gd'
(no output)
```

Only `default_env.tres` exists. **No `main.tscn`.** No GDScript files.

### `project.godot` reference

```text
run/main_scene="res://default/main.tscn"
```

The scene file `default/main.tscn` is referenced by `project.godot` at line 7 but **does not exist** in the template. Opening this project in the Godot editor for the first time will show an error about the missing main scene.

### Verdict: **GAP FOUND**
Template declares `run/main_scene="res://default/main.tscn"` but no `default/main.tscn` file exists. This will cause an editor error on first open.

---

## Task 6: Mono vs Non-mono

### Current flake.nix reference

```text
Line 19:    godot
```

Just `godot` — the bare attribute name with no override.

### Package identity

```text
$ nix eval nixpkgs#godot.name
"godot-4.6.3-stable"

$ nix eval nixpkgs#godot.meta.description
"Free and Open Source 2D and 3D game engine"
```

This is the **non-mono** (GDScript-only) build.

### Mono variant exists

```text
$ nix eval nixpkgs#godot-mono.name
derivation /nix/store/...-godot-mono-wrapper-4.6.3-stable.drv

$ nix eval nixpkgs#godot-mono.meta.description
"Free and Open Source 2D and 3D game engine"
```

`godot-mono` (a wrapper adding Mono/C# support) is available in nixpkgs but the template does not reference it.

### Verdict: **NEEDS DECISION**
Template uses non-mono `godot` (GDScript-only). If C# scripting is intended, `godot-mono` must be used and `dotnet-sdk` added to dev shell packages. Current config matches a GDScript-only project, which is the most common Godot 4 workflow — but this should be confirmed as intentional.

---

## Summary Table

| # | Task | Verdict |
|---|---|---|
| 1 | MCP tool audit — destructive auto-approvals | **GAP FOUND** — 7 destructive tools auto-approved |
| 2 | Reproducibility — unpinned MCP server | **GAP FOUND** — no lockfile, live `npx` fetch |
| 3 | GPU test — AMD desktop clean, laptop offline | **NEEDS DECISION** — laptop testing required |
| 4 | Export templates — missing presets + CI | **GAP FOUND** — 3 gaps (no presets, no pkg, no check) |
| 5 | Scene file — main.tscn missing | **GAP FOUND** — referenced but absent |
| 6 | Mono vs non-mono | **NEEDS DECISION** — non-mono (GDScript), likely correct but unconfirmed |
