---
description: Audit the NixOS flake config — map structure, find duplication, inventory modules
---

You are a NixOS configuration auditor working inside the nixos-config repo.
This command is **read-only**. Never modify files.
**Never summarise file contents. Always quote or paste raw output.**

---

## AVAILABLE NIX-GRAPH TOOLS (MCP)

The `nix-graph` MCP server provides pre-computed static analysis of the config graph
(v1 scope: ~120 key files). Use these tools to supplement shell-based exploration:

| Tool | When to use |
|------|-------------|
| `nix-graph_graph_stats` | Overall node/edge counts, module/host/option distribution |
| `nix-graph_search_nodes(query)` | Find modules, hosts, or options by substring |
| `nix-graph_node_info(node_id)` | Get metadata for a specific module or file |
| `nix-graph_get_dependents(module_path)` | Find all files that import a given module |
| `nix-graph_get_option_definers(option_path)` | Find where an option is declared/defined |
| `nix-graph_find_mkforce_sites` | All `lib.mkForce` usage sites |
| `nix-graph_find_namespace_violations` | Options set outside `my.*` namespace |
| `nix-graph_find_path(source, target)` | Shortest path between two nodes in the import graph |

Node IDs use prefixes: `option:`, `module:`, `host:`, `mk:`, `external:`, `violation:`.
Partial paths match via suffix (e.g. `"tailscale"` matches `"modules/nixos/tailscale"`).

---

## LIVE CONTEXT

Use nix-graph for the initial structural overview:

```
nix-graph_graph_stats
nix-graph_search_nodes("host:")
nix-graph_search_nodes("module:nixos/")
nix-graph_search_nodes("module:home/")
nix-graph_find_namespace_violations
nix-graph_find_mkforce_sites
```

Then supplement with shell exploration for data outside the v1 scope:

Current file tree (Nix files only):
!`find . -name '*.nix' -not -path './.git/*' -not -path './secrets/*' | sort`

Line counts (heaviest files first):
!`find . -name '*.nix' -not -path './.git/*' -not -path './secrets/*' | xargs wc -l 2>/dev/null | sort -rn | head -40`

Active hosts:
!`ls configurations/nixos/`

Flake inputs declared:
!`grep -E '^\s+[a-zA-Z_-]+\.url' flake.nix`

---

## Approach

Use the opencode-ensemble skill to parallelise the read-only audit. Create a team,
spawn scouts for the sections below, then collect and synthesise their results.

M1 and M5 depend on M0 (live context), so run them after the live context is gathered.

### Team plan

1. `scout-hosts` (scout, worktree=false) — M1. Host assembly.
2. `scout-modules` (scout, worktree=false) — M2. Module inventory.
3. `scout-profiles` (scout, worktree=false) — M3. Profile coverage.
4. `scout-duplication` (scout, worktree=false) — M4. Cross-cutting duplication.
5. `scout-inputs` (scout, worktree=false) — M5. Input hygiene.

All five scouts are independent and can run in parallel.

Each scout must return findings in the format specified below with file paths and line numbers.
After all scouts report, synthesise the results into M6 (architecture summary).

---

## M1. Host assembly

Use nix-graph to discover hosts and their module dependencies:

```
nix-graph_search_nodes("host:")
# For each host:
nix-graph_node_info("host:laptop")
nix-graph_get_dependents("configurations/nixos/laptop")
```

For each directory under `configurations/nixos/`:
- Read its `default.nix`. List every `imports = [...]` entry.
- List every option set **inline** (i.e. not via an imported module) as `path.to.option = <value or type>`.
- Flag any inline option that also appears to be set inside a shared module (duplication suspect).
- Cross-reference with nix-graph: use `nix-graph_get_option_definers("my.foo.bar")` to find all definition sites.

Format:
```
### <hostname>
imports: [list]
inline options:
  - my.foo.bar = true
duplication suspects:
  - my.foo.bar (also set in modules/nixos/foo/config.nix:42 — confirmed by nix-graph)
```

## M2. Module inventory

Use nix-graph to discover all extracted modules and their option declarations:

```
nix-graph_search_nodes("module:nixos/")
nix-graph_search_nodes("module:home/")
# For each module, inspect its options:
nix-graph_node_info("module:nixos/tailscale")
nix-graph_get_option_definers("my.services.tailscale.enable")
```

For each module directory under `modules/nixos/` and `modules/home/`:
- State its purpose in one sentence.
- List declared `options.my.*` keys (or NONE) — cross-reference with nix-graph `node_info`.
- Note if it has a cross-layer peer (NixOS ↔ HM).
- Quote any hard-coded value that should come from `config.nix` or a host file (username, absolute path, hostname, hardware ID).

## M3. Profile coverage

Use nix-graph to discover profile dependents:

```
nix-graph_search_nodes("module:nixos/profiles")
# Find which hosts/modules import each profile:
nix-graph_get_dependents("modules/nixos/profiles/system/workstation.nix")
nix-graph_get_dependents("modules/nixos/profiles/system/server.nix")
```

Read every file under `modules/nixos/profiles/`.
For each profile: list what it enables and which hosts import it (cross-reference with nix-graph `get_dependents`).
Flag any option a profile enables that is also set inline in a host file (override duplication).

## M4. Cross-cutting duplication

Use nix-graph for structural duplicate analysis first:

```
# Find all mkForce sites — these are intentional override points that may indicate duplication
nix-graph_find_mkforce_sites

# Find all namespace violations — options set outside my.* that may need consolidation
nix-graph_find_namespace_violations

# Find all files that define options in the same namespace
nix-graph_get_option_definers("my.profiles")
nix-graph_get_option_definers("my.services")
nix-graph_get_option_definers("my.programs")
```

Then supplement with grep-based scanning of all `.nix` files:

**M4a — Repeated package lists**
Any `systemPackages`/`home.packages` list sharing ≥ 2 packages across ≥ 2 files.
Quote the relevant lines and both paths.

**M4b — Repeated user/group definitions**
`users.users.<name>` blocks appearing in multiple files.
Quote each occurrence.

**M4c — Theme/colour duplication**
Stylix values or colour palette fragments appearing in more than one file.

**M4d — Stray inline config**
`.nix` files outside `modules/` that contain `config =` or `options =` blocks, or large inline option sets that belong in a module.

## M5. Input hygiene

For each flake input in `flake.nix`:
- State whether it is referenced anywhere in the repo (`grep -r <name> modules/ configurations/`).
- Flag missing `inputs.nixpkgs.follows` where relevant.
- Flag duplicate-purpose inputs (e.g. two inputs pointing at the same branch).

## M6. Architecture summary

Include key nix-graph statistics for context:

```
nix-graph_graph_stats
```

Write ≤ 15 lines describing:
- How a host is assembled (flake → configurations → modules → profiles).
- Where the branch point between desktop/laptop/server currently lives.
- The top 5 structural issues found above, in priority order.
- Graph metrics: total nodes/edges, module/option/host counts from nix-graph.

---

**MAP COMPLETE.** Review the output above. When you're ready to act on the findings, run the `nix-refine` command.
