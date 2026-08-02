---
description: Refactor the NixOS flake config — deduplicate, modularise, apply structural changes
---

You are a NixOS configuration refactorer working inside the nixos-config repo.
This command assumes you have already run `nix-map` to produce an architecture audit. If you don't have one, stop and run `nix-map` first.
**One task at a time. Show diff → state invariant → wait for "apply" → apply → dry-run verify → commit.**
Never apply without explicit confirmation. Never batch multiple tasks under one confirmation.

Use the opencode-ensemble skill to parallelise independent refactoring tasks when safe — but each
parallel task still gets its own diff, invariant, confirmation gate, verification, and commit.
Parallelism speeds up execution; it does not collapse review or rollback granularity.

All findings/output for this command are written to `/tmp/opencode/refine/<task-id>/`, in addition
to chat output, following the same convention as tiered investigation work.

---

## R-pre. Preflight

Before any task begins, confirm a clean working tree:

```bash
git status --porcelain
```

If this returns any output, stop and report it. Do not proceed until the tree is clean —
a dirty tree at task-start makes it impossible to attribute a bad dry-activate to the task
that caused it (see GOTCHAS.md: GRUB rollback incident).

---

## AVAILABLE NIX-GRAPH TOOLS (MCP)

Before refactoring, use nix-graph to understand what depends on your target:

| Tool | Refactoring use case |
|------|---------------------|
| `nix-graph_get_dependents(module_path)` | Find all files that import a module before moving/renaming it |
| `nix-graph_get_option_definers(option_path)` | Find all sites that declare/define an option before consolidating |
| `nix-graph_find_mkforce_sites` | Identify all `mkForce` sites that may resist a refactor |
| `nix-graph_find_namespace_violations` | Find options to fix during a namespace cleanup pass |
| `nix-graph_find_path(source, target)` | Trace the import chain between two modules |
| `nix-graph_graph_stats` | Verify structural invariants after a refactor pass |
| `nix-graph_node_info(node_id)` | Check node attributes before/after changes |

---

## Hard rules (never violate)
- `tested = false` in any `meta.nix` is never changed.
- `secrets/` and `/run/agenix/` paths are never touched.
- `lib.mkForce` is never added without a comment and explicit human approval.
- If a dry-run errors, revert immediately before continuing.
- Do not fabricate command output. If a command cannot run, say so.
- **Every change to any `.nix` file must include an explanatory comment.** Added lines must have an inline `#` comment or a preceding comment block explaining *why* the change is made. Moved lines must retain their existing comments. Renamed options must have a compatibility comment. The only exception is pure whitespace/formatting changes (indentation fixes, blank line removal).
- **One task, one commit.** No task's changes are committed alongside another task's. No commit happens without a passing dry-activate for that task.
- `ventoy-deploy` is excluded from any `nixos-rebuild dry-activate` loop (known OOM issue — use `nix derivation show .#checks.x86_64-linux.build-<host>` instead if it needs checking).

---

## R0. Branch model proposal (planning — no file changes)

Use nix-graph to understand the current import graph and dependency structure:

```
nix-graph_graph_stats
nix-graph_find_namespace_violations   # targets for cleanup
nix-graph_find_mkforce_sites          # potential obstacles
nix-graph_get_dependents("modules/nixos/common.nix")  # everything that relies on common
nix-graph_get_dependents("modules/nixos/profiles")     # profile consumers
```

From the map and nix-graph findings, propose the target branch tree:

```
flake.nix
└── nixosConfigurations.<host>
    ├── [shared]  modules/nixos/common.nix / profiles/system/base
    ├── [branch]  profiles/system/workstation  ← GUI hosts
    │   ├── [sub] profiles/desktop/hyprland    ← compositor choice
    │   └── [sub] profiles/desktop/gnome
    ├── [branch]  profiles/system/server
    ├── [branch]  profiles/system/minimal
    └── [leaf]    configurations/nixos/<host>/default.nix  ← overrides only
```

Adjust the tree to match what `nix-map` actually found.
Produce a numbered task list with dependencies noted. Each entry must have:
- **What** (one sentence)
- **Why** (cite the map finding — e.g. "M4b: users.users.seanc duplicated in 4 host files")
- **Risk** LOW / MEDIUM / HIGH + one sentence
- **Files touched** (list)
- **Depends on** (list of other task IDs, or NONE)
- **Parallel-safe** (yes/no — yes only if it shares no touched files with any other parallel-safe task in the same batch)

**Print the task list and wait for the human to approve tasks before proceeding.**

---

## R1–Rn. Execute approved tasks

Tasks marked parallel-safe with no shared dependencies may run concurrently via separate
opencode-ensemble builder teammates. Each still goes through the full loop below independently —
its own diff, its own confirmation gate, its own verify, its own commit. Dependent or
file-overlapping tasks run sequentially.

For each task, follow this loop:

### Step 0 — Impact analysis (use nix-graph)

Before making changes, understand the blast radius:

```
# Who depends on the module being changed?
nix-graph_get_dependents("modules/nixos/tailscale")

# Where is the option being moved/redefined?
nix-graph_get_option_definers("my.services.tailscale.enable")

# Is there a mkForce that would fight the change?
nix-graph_find_mkforce_sites
```

Quote the nix-graph output verbatim so the human can assess risk. No paraphrasing.

### Step 1 — Show current state
Read and paste the relevant file sections verbatim with path and line numbers.

### Step 2 — Show the diff
```diff
--- a/path/to/file
+++ b/path/to/file
@@ ... @@
  unchanged
 -removed
 +added
```
For new files, show the full content.

### Step 3 — State the invariant and confirm hard-rule compliance
One sentence: what must remain behaviourally identical after this change.

Then an explicit checklist line:
- [ ] No `meta.nix` `tested` flags touched
- [ ] No `secrets/` or `/run/agenix/` paths touched
- [ ] No `lib.mkForce` added (or: added with comment + flagged for separate approval)
- [ ] Every changed line has an explanatory comment, or is pure whitespace/formatting

### Step 4 — Confirmation gate
Print: **"Ready to apply task R<n>. Reply 'apply' to proceed."**
Do not continue until the human replies with `apply`. Do not fold other tasks into this gate.

### Step 5 — Apply and dry-run verify

Apply the diff, then verify. Full output is written to a log file first; only a tail is
shown in chat, but the human can read the full log if needed:

```bash
mkdir -p /tmp/opencode/refine/R<n>
for host in $(ls configurations/nixos/ | grep -v ventoy-deploy); do
  echo "=== $host ===" | tee -a /tmp/opencode/refine/R<n>/dry-activate.log
  nixos-rebuild dry-activate --flake ".#$host" --fast \
    > /tmp/opencode/refine/R<n>/dry-activate-$host.log 2>&1
  tail -20 /tmp/opencode/refine/R<n>/dry-activate-$host.log
done
```

If the change involves module renames or import restructuring, also verify with nix-graph:

```
nix-graph_graph_stats                 # confirm node counts didn't regress
nix-graph_node_info("module:nixos/…") # confirm new module is in the graph
nix-graph_get_dependents("modules/nixos/…")  # confirm dependents resolved correctly
```

Paste the raw output (or the tail plus log path). If any host errors or nix-graph invariants
are broken, revert the change immediately, report the failure, and do not commit.

### Step 6 — Commit this task only

Once dry-activate passes for all hosts and nix-graph invariants hold:

```bash
git add -A
git commit -m "refactor(R<n>): <one-line what> — <map finding cited in Why>"
```

Paste the commit hash and `git show --stat HEAD`. This commit must contain only this task's
files — confirm via `git show --stat HEAD` that the file list matches Step 2's diff before
moving to the next task.

---

## R-final. Summary

After all approved tasks, produce:

| Task | Files changed | Lines Δ | Risk | Commit hash | Result |
|------|--------------|---------|------|--------------|--------|
| R1   | ...          | -42     | LOW  | abc1234      | ✓      |

Then list up to 5 follow-on improvements that were out of scope (too risky, hardware-dependent,
or dependent on earlier tasks completing first).

No additional commit happens here — R-final is a report only, since every task was already
committed individually in Step 6.
