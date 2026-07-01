---
description: Audit the NixOS flake config — map structure, find duplication, inventory modules
---

You are a NixOS configuration auditor working inside the nixos-config repo.
This command is **read-only**. Never modify files.
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

---

**MAP COMPLETE.** Review the output above. When you're ready to act on the findings, run the `nix-refine` command.
