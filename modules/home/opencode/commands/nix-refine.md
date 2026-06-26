---
description: Map and refine the NixOS flake config — audit structure, deduplicate, modularise
---

You are a NixOS configuration auditor and refactorer working inside the nixos-config repo.
This command runs in two sequential phases. Complete Phase 1 in full before starting Phase 2.
**Never summarise file contents. Always quote or paste raw output.**

---

## LIVE CONTEXT

Current file tree (Nix files only):
!`find . -name '*.nix' -not -path './.git/*' -not -path './secrets/*' | sort`

Line counts (heaviest files first):
!`find . -name '*.nix' -not -path './.git/*' -not -path './secrets/*' | xargs wc -l 2>/dev/null | sort -rn | head -40`

Active hosts:
!`ls configurations/nixos/`

Flake inputs declared:
!`grep -E '^\s+[a-zA-Z_-]+\.url' flake.nix`

---

# PHASE 1 — MAP (read-only, no changes)

Work through every section below. Do not skip any. Every claim requires a file path citation.

## M1. Host assembly

For each directory under `configurations/nixos/`:
- Read its `default.nix`. List every `imports = [...]` entry.
- List every option set **inline** (i.e. not via an imported module) as `path.to.option = <value or type>`.
- Flag any inline option that also appears to be set inside a shared module (duplication suspect).

Format:
```
### <hostname>
imports: [list]
inline options:
  - my.foo.bar = true
duplication suspects:
  - my.foo.bar (also set in modules/nixos/foo/config.nix:42)
```

## M2. Module inventory

For each module directory under `modules/nixos/` and `modules/home/`:
- State its purpose in one sentence.
- List declared `options.my.*` keys (or NONE).
- Note if it has a cross-layer peer (NixOS ↔ HM).
- Quote any hard-coded value that should come from `config.nix` or a host file (username, absolute path, hostname, hardware ID).

## M3. Profile coverage

Read every file under `modules/nixos/profiles/`.
For each profile: list what it enables and which hosts import it.
Flag any option a profile enables that is also set inline in a host file (override duplication).

## M4. Cross-cutting duplication

Scan all `.nix` files and report:

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

Write ≤ 15 lines describing:
- How a host is assembled (flake → configurations → modules → profiles).
- Where the branch point between desktop/laptop/server currently lives.
- The top 5 structural issues found above, in priority order.

**— STOP HERE. Print "MAP COMPLETE" and wait. —**
**Do not begin Phase 2 until you have printed MAP COMPLETE.**

---

# PHASE 2 — REFINE (changes with confirmation gates)

Use the map from Phase 1 as your working reference.
**One task at a time. Show diff → state invariant → wait for "apply" → apply → dry-run verify.**
Never apply without explicit confirmation.

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

Adjust the tree to match what Phase 1 actually found.
Produce a numbered task list. Each entry must have:
- **What** (one sentence)
- **Why** (cite the Phase 1 finding — e.g. "M4b: users.users.seanc duplicated in 4 host files")
- **Risk** LOW / MEDIUM / HIGH + one sentence
- **Files touched** (list)

**Print the task list and wait for the human to approve tasks before proceeding.**

---

## R1–Rn. Execute approved tasks

For each approved task, follow this loop exactly:

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
