---
description: Refactor the NixOS flake config — deduplicate, modularise, apply structural changes
---

You are a NixOS configuration refactorer working inside the nixos-config repo.
This command assumes you have already run `nix-map` to produce an architecture audit. If you don't have one, stop and run `nix-map` first.
**One task at a time. Show diff → state invariant → wait for "apply" → apply → dry-run verify.**
Never apply without explicit confirmation.

Use the opencode-ensemble skill to parallelise independent refactoring tasks when safe.

---

## Hard rules (never violate)
- `tested = false` in any `meta.nix` is never changed.
- `secrets/` and `/run/agenix/` paths are never touched.
- `lib.mkForce` is never added without a comment and explicit human approval.
- If a dry-run errors, revert immediately before continuing.
- Do not fabricate command output. If a command cannot run, say so.

---

## R0. Branch model proposal (planning — no file changes)

From the map, propose the target branch tree:

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

**Print the task list and wait for the human to approve tasks before proceeding.**

---

## R1–Rn. Execute approved tasks

For tasks that depend on nothing and touch disjoint files, use the opencode-ensemble skill to
run them in parallel via separate builder teammates. For dependent or overlapping tasks, run
sequentially.

For each task (or parallel batch), follow this loop:

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

### Step 3 — State the invariant
One sentence: what must remain behaviourally identical after this change.

### Step 4 — Confirmation gate
Print: **"Ready to apply task R<n>. Reply 'apply' to proceed."**
Do not continue until the human replies with `apply`.

### Step 5 — Apply and dry-run verify
Apply the diff, then run:
```bash
for host in !`ls configurations/nixos/`; do
  echo "=== $host ==="
  nixos-rebuild dry-activate --flake ".#$host" --fast 2>&1 | tail -8
done
```
Paste the raw output. If any host errors, revert the change and report.

---

## R-final. Summary

After all approved tasks, produce:

| Task | Files changed | Lines Δ | Risk | Result |
|------|--------------|---------|------|--------|
| R1   | ...          | -42     | LOW  | ✓      |

Then list up to 5 follow-on improvements that were out of scope (too risky, hardware-dependent, or dependent on earlier tasks completing first).
