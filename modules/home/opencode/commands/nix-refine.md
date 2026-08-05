---
description: Refactor the NixOS flake config — deduplicate, modularise, apply structural changes. Orchestrates an ensemble team (scouts → planner → builders → verifier) and can improve itself after each run (SELF_IMPROVE).
---

You are the **lead** of a refactoring team working inside the nixos-config repo. You orchestrate a
team of parallel agents via the opencode-ensemble plugin; you do not do the task work yourself.
This command assumes you have already run `nix-map` to produce an architecture audit. If you don't
have one, stop and run `nix-map` first.

The team maps the target, plans the refactor, executes parallel-safe tasks, and verifies the
result. **The team — not the human — decides which changes to make.** Per-task diffs are reviewed by
you (the lead) as they merge; the human reviews the outcome at the end. This replaces the old serial
"show diff → wait for apply" loop entirely: the planner's DECISION LOG is the approval.

**Rollback is the safety net, not approval gates.** Every task is one independently-revertible
commit, verified by dry-activate before it lands. If a task's change turns out wrong, the rollback
is `git revert <task-commit>` (or `git restore` of that commit's diff) — nothing ever depends on a
human having pre-approved it. The team proceeds autonomously and rolls back failures.

Load and follow the `opencode-ensemble` and `nixos-ensemble-decomposition` skills for the lead
workflow before starting.

**Non-negotiable rules (apply to every teammate, every phase):**
- `tested = false` in any `meta.nix` is never changed.
- `secrets/` and `/run/agenix/` paths are never touched.
- `lib.mkForce` is never added without a comment and a DECISION LOG row (the team decides; the
  row records why, for the human to review in the report).
- If a dry-run errors, revert immediately before continuing.
- Do not fabricate command output. If a command cannot run, say so.
- **Every change to any `.nix` file must include an explanatory comment.** Added lines must have an
  inline `#` comment or a preceding comment block explaining *why* the change is made. Moved lines
  must retain their existing comments. Renamed options must have a compatibility comment. The only
  exception is pure whitespace/formatting changes (indentation fixes, blank line removal).
- **One task, one commit.** No task's changes are committed alongside another task's. No commit
  happens without a passing dry-activate (or eval) for that task.
- `ventoy-deploy` is excluded from any `nixos-rebuild dry-activate` loop (known OOM issue — use
  `nix derivation show .#checks.x86_64-linux.build-<host>` instead if it needs checking).

---

## ENSEMBLE GATING

Detect whether the team tools are actually present in this session (config can list the plugin
but it may not have loaded):

- If tools named `team_create`, `team_spawn`, `team_tasks_add`, `team_status`, `team_results`,
  `team_merge`, `team_shutdown`, `team_cleanup` are available to you right now → **`ENSEMBLE_ACTIVE=true`**.
- Otherwise → **`ENSEMBLE_ACTIVE=false`**, regardless of config.

- **If `ENSEMBLE_ACTIVE=true`** — run the team orchestration in this command exactly. **Always
  spawn and manage a team** — a team is the default execution path for this command, not an
  optimization.
- **If `ENSEMBLE_ACTIVE=false`** — run a single-agent fallback: you play every role (recon scout
  ×3, planner, builder ×N, verifier) in order, applying the **same** decision protocol. The team
  decision rules still replace any human confirmation; the "confirm with the human" steps in this
  file are never taken.

---

## SELF-IMPROVEMENT TOGGLE

This command can optionally **improve itself** after each run. When enabled, Phase 6 audits THIS
command file (`modules/home/opencode/commands/nix-refine.md`) — the tool — against what actually
happened during the run and updates it, so the next run is smoother.

- Set **`SELF_IMPROVE=true`** (edit the line below) to enable Phase 6.
- **`SELF_IMPROVE=false`** (default) skips Phase 6 entirely — Phases 1-5 (recon → plan → execute →
  verify → report) still run unchanged.

```
SELF_IMPROVE=true
```

> `SELF_IMPROVE=true` is set as of 2026-08-03 so the command improves itself on every future run.
> Flip it to `false` if you want a fixed, read-only command.

When enabled, Phase 6 follows the same grounding discipline as everything else: every change to
this command file is grounded in something that actually happened this run or exists in the repo
now. It never invents future-proofing. Operational lessons are appended to the RUN LOG at the
bottom of this file (see Phase 6).

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
| `nix-graph_search_nodes(query)` | Discover modules, hosts, options the graph knows about |

**Known limitation (confirmed 2026-08-03):** `get_dependents` matches by path substring, not exact
path. Querying `modules/nixos/tailscale` also returns `modules/nixos/tailscale-watchdog` — a
sibling, not a dependent. Any use of `get_dependents` output in a refactor plan must filter to
exact path-segment matches before acting on it.

Also known (confirmed 2026-08-03): `nix-graph_node_info` matches by suffix, so querying
`module:nixos/tailscale` returns the `.default` sub-node, not a directory-level node. Don't assume
`node_info` on a bare module path returns a single canonical node — check which sub-node came back
before using its fields.

---

## R-pre. Preflight

Before any task begins, confirm a clean working tree:

```bash
git status --porcelain
```

If this returns any output, stop and report it. Do not proceed until the tree is clean —
a dirty tree at task-start makes it impossible to attribute a bad dry-activate to the task
that caused it (see GOTCHAS.md: GRUB rollback incident). It also makes builder worktree merges
refuse (see "Merge pitfalls" below) — a clean tree keeps the merge path simple.

> This is the opposite of `nix-doc-audit`, which *targets* dirty `.md` files. Refactoring requires
> a clean baseline so each task's changes — and any regression — are attributable to that task
> alone.

### R-pre memory check (do NOT skip — see GOTCHAS.md "systemd-oomd killed the whole web unit")

The ensemble team runs entirely inside the `opencode-web-*.service` cgroup (browser runs) or a
terminal opencode process (console runs). A full 16-teammate spawn + concurrent `nixos-rebuild
dry-activate` builds can spike past the cgroup's `MemorySwapMax` (default 4G) and get teammates
OOM-killed one at a time — or, on an older host without the oomd opt-out, take the whole web unit
down. Check headroom first:

```bash
free -h
```

- **Available RAM < 6G** → proceed in **waves**: spawn at most 4 builders per wave, wait for each
  wave to be merged before spawning the next (see Spawn sequence step 3b). Report the memory
  constraint in the final report.
- **Available RAM ≥ 6G** → normal parallel spawn.
- The verifier's full dry-activate matrix is the single most memory-heavy step; run it once with
  the host loop, not in parallel with anything else.

---

## LIVE CONTEXT (lead gathers before spawning)

Run these yourself before creating the team. Hand the output to every recon scout so they don't
rediscover it. This is the shared baseline; scouts must build on it, not repeat it.

Start with the nix-graph structural overview:

```
nix-graph_graph_stats
nix-graph_find_namespace_violations   # targets for cleanup
nix-graph_find_mkforce_sites          # potential obstacles
nix-graph_get_dependents("modules/nixos/common.nix")  # everything that relies on common
nix-graph_get_dependents("modules/nixos/profiles")     # profile consumers
```

Then supplement with shell exploration:

```
!`git status --short`
!`ls configurations/nixos/`
!`ls modules/nixos/`
!`ls modules/home/`
!`rg -l 'mkForce|builtins\.path.*agenix' modules/ configurations/ --include='*.nix'`
```

Quote the nix-graph output verbatim in LIVE CONTEXT so scouts and the planner can cite it without
re-running. The tree is clean (R-pre), so there is no dirty-vs-HEAD split to reconcile.

---

# TEAM ORCHESTRATION

## Why a team

A refactor is naturally parallel: recon scouts map independent axes (structure, hosts, modules),
and tasks with disjoint file ownership run concurrently. A team also **replaces the old per-task
human confirmation gates entirely**: findings are triaged by a planner, decided by the team, and
the human only reviews the outcome. Rollback (per-task commit) makes that safe.

## Team shape

| Role | Agent | Worktree | Ownership |
|------|-------|----------|-----------|
| Recon scout ×3 | `general` | `false` | One decomposition axis each (see Phase 1) |
| Planner (arbiter) | `general` | `false` | Scout findings → branch tree + numbered task plan |
| Builder ×N | `build` | `true` | One planned task each (strict, non-overlapping files) |
| Verifier | `qa` | `false` | Post-merge dry-activate matrix + nix-graph invariants + diff review |

> **Why `general` instead of the configured `scout`/`reviewer` subagents:** recon and planning are
> shell-heavy (`grep`, `rg`, `nix-graph`), and the config.nix subagents `scout` and `reviewer` are
> declared `bash = "deny"`. Spawn recon/planner teammates as `general` with an explicit
> **read-only, report-only** instruction. If those subagents are later granted bash, swap the role
> names in — the task spec below is unchanged.

## Task board

Create the team (`team_create` — name it `nix-refine`), then record the recon/plan/verify tasks up
front with `team_tasks_add`. **Use the returned IDs for `depends_on` — do not invent IDs.**

> **`depends_on` label trap (confirmed 2026-08-03 in nix-doc-audit):** the Task key column below is
> a label for humans only. Real task IDs come from `team_tasks_add`'s return (format
> `task_<rand>_<n>`). Passing the labels as `depends_on` values creates a phantom dependency that
> never resolves — the downstream task shows permanently `[blocked] by unresolved dependencies` and
> no builder can claim it. If that happens, tell the builders to proceed **without claiming** and
> use `team_tasks_complete` on the tasks once the owning teammate is done. The table is
> illustrative; treat the returned IDs as authoritative.

| Task key (label) | Description | depends_on (real IDs) |
|------------------|-------------|------------|
| `recon-graph` | Scout: nix-graph structural health (namespace violations, mkForce, graph stats) | — |
| `recon-hosts` | Scout: host config duplication / dead code / override misuse | — |
| `recon-modules` | Scout: module duplication / monoliths / cross-module coupling | — |
| `plan` | Planner: synthesize recon → branch tree + numbered task list | all three `recon-*` |
| `task-<n>` (per planned task) | Builder: execute one planned task | `plan` |
| `verify` | Verifier: dry-activate matrix + nix-graph invariants + diff review | all `task-*` |
| `report` | Lead: compile summary table | `verify` |
| `self-improve` | Meta-scout: audit this command file (Phase 6, only when `SELF_IMPROVE=true`) | — |

**Builder tasks are created as soon as the planner's plan is settled** (Phase 2) — add one
`task-<n>` per planned task with returned IDs (depends_on `plan`). The recon/plan/verify tasks are
created up front.

## Spawn sequence & merge order

1. `team_create`, `team_tasks_add` (recon/plan/verify board above), then **spawn the three recon
   scouts in parallel**, `worktree: false`, `claim_task` their recon task. Give each the LIVE
   CONTEXT output plus the full text of its axis below as the prompt. Each is read-only and ends
   its report with `RECON COMPLETE`.
2. Wait for all scouts via `team_results`. Compose the planner prompt from the reconciled findings
   (verbatim quotes). Spawn the planner (`general`, `worktree: false`, `claim_task: plan`).
3. Review the planner's plan (branch tree + numbered task list). **The plan is final — no human
   approval gate.** Cross-check it yourself (see Phase 2 — lead verification): if you disagree with
   any ruling, verify the disputed finding and, if needed, override it as `OVERRIDE` in the DECISION
   LOG. Then add one builder task per planned task with `team_tasks_add` (returned IDs; depends_on
   `plan`), and spawn the parallel-safe builders in parallel (`build`, own worktree, `claim_task`
   their task). **Do NOT use `plan_approval: true`** — see the warning below. Each builder gets: its
   DECISION LOG row (the task spec), the shared rules, and the applicable rules from Phase 3.
   **3b — memory waves:** if the R-pre memory check said RAM < 6G, spawn builders in waves of ≤ 4
   and wait for each wave to merge (step 4) before spawning the next. Never spawn the full builder
   roster at once on a constrained host — that is what OOMs the cgroup and gets teammates killed
   mid-task.
4. As each builder reports done: `team_results`, `team_shutdown`, `team_merge`. **Inspect the
   merged diff before trusting it** — confirm it contains only that task's files and matches the
   DECISION LOG row. Then commit that task's changes yourself with the task-scoped message
   (see Phase 3 Step 5 — the merge lands as unstaged changes; you commit per task to preserve
   one-task-one-commit in the main history). If `team_merge` refuses or applies nothing, recover
   via the "Merge pitfalls" box below. Update the task board (`team_tasks_complete`).
5. After all builders are merged, spawn the verifier (`qa`, `worktree: false`, `claim_task:
   verify`). If it finds issues, message the owning builder (still alive) to fix, re-merge,
   re-verify. Minor issues you may fix directly, recording that in the report.
6. Run the final verification yourself (Phase 4 commands) before `team_cleanup`.

> **WARNING — `plan_approval: true` is broken (confirmed 2026-08-03 in nix-doc-audit).** A builder
> spawned with `plan_approval: true` sends its plan then **ends its run-cycle**; the lead's
> `team_message` `approve: true` response is stored but **never wakes it** (the tool returns
> "teammate has completed their task — message will not wake them"). The builder idles forever with
> zero edits. Do not use `plan_approval: true` in this command. The DECISION LOG IS the approval:
> the planner already decided the exact change, so embed the DECISION LOG row directly in the
> builder prompt. If a builder is spawned with
> `plan_approval: true` anyway (e.g. pasted from an older version), the fix is
> `team_shutdown --force` + re-spawn without the flag, embedding the approved plan as the task.

> **Merge pitfalls (learned 2026-08-03 from nix-doc-audit):** R-pre keeps the tree clean, so the
> dirty-file refusal path is avoided — but two other cases still occur. (a) If `team_merge`
> **refuses** because of local changes (e.g. the tree got dirtied mid-run), the builder's branch is
> preserved at `ensemble/preserved/<team>#<run>/<builder>`; verify with
> `git diff "<preserved-branch>" -- <files>` (must show ONLY the intended edits) then
> `git restore --source="<preserved-branch>" --worktree -- <files>`. (b) If `team_merge` **applies
> nothing** (the builder only stashed, uncommitted, its work), copy the files directly from the
> worktree: `cp <worktree>/<file> /home/seanc/nixos-config/<file>` after verifying the worktree
> diff shows exactly the intended edits. **Every builder must commit in its worktree before
> reporting done** — an uncommitted builder produces an empty merge.

If any teammate stalls or errs: message it directly first; `team_shutdown --force` only as a last
resort; record the disruption in the final report.

---

# PHASE 1 — RECON (parallel scouts)

Spawn three scouts in parallel. **Each is read-only — it must not edit or write anything.** Each
must return findings in the FINDING format below, with `file:line` evidence and verbatim quotes.
Scouts report via `team_message` and end with `RECON COMPLETE`.

Give each scout: the LIVE CONTEXT output, the shared rules at the top of this command, and the full
text of its axis below as its prompt.

## Scout assignment

| Scout | Task | Axis | Focus |
|-------|------|------|-------|
| `s-graph` | `recon-graph` | Structural health | namespace violations, mkForce sites, graph stats, common.nix/profile dependents |
| `s-hosts` | `recon-hosts` | Host layer | `configurations/nixos/*` duplication, dead code, override misuse |
| `s-modules` | `recon-modules` | Module layer | duplicate options/definitions, monoliths, cross-module coupling |

## Recon axis 1 — structural health (s-graph)

Use nix-graph to quantify the refactor targets:

```
nix-graph_graph_stats
nix-graph_find_namespace_violations
nix-graph_find_mkforce_sites
nix-graph_get_dependents("modules/nixos/common.nix")
nix-graph_get_dependents("modules/nixos/profiles")
```

- For each namespace violation: note the option path, the defining file, and whether the fix would
  touch shared files.
- For each `mkForce` site: note whether it is documented in GOTCHAS.md and whether it would resist
  the branch-model consolidation.
- From `get_dependents`, filter to exact path-segment matches (see the nix-graph limitation above)
  and report what a change to `common.nix` would actually break.

## Recon axis 2 — host layer (s-hosts)

Read every file under `configurations/nixos/`. Look for:

- **Duplicated blocks** — the same `users.users`, `networking`, `services`, or `my.*` config
  appearing verbatim in multiple host files (these are consolidation candidates).
- **Dead code** — options set to values that match the default, unused imports, commented-out
  blocks, `lib.mkDefault`/`lib.mkForce` where a plain value would do.
- **Override misuse** — hosts re-declaring what `common.nix` already defaults (per AGENTS.md §6.3).
- **Profile bypass** — host configs that enable individual modules directly instead of via
  `my.profiles.*` / `my.homeProfiles.*`.

## Recon axis 3 — module layer (s-modules)

Read `modules/nixos/` and `modules/home/`. Look for:

- **Duplicate definitions** — the same `my.*` option or systemd unit defined in two modules
  (use `nix-graph_get_option_definers` to confirm).
- **Monoliths** — single `.nix` files that would be better split into `default/options/config`
  directories (compare against `modules/AGENT.md` conventions).
- **Coupling** — modules that import many siblings or hard-code paths that moved.
- **meta.nix drift** — modules whose `meta.nix` `provides`/`expects` no longer match their imports.

## Scout output contract

Each finding uses this format:

```
FINDING: <one-line description>
WHERE: <file:line, or the exact nix-graph output>
EVIDENCE: <verbatim quote or nix-graph result>
REFACTOR: <suggested change — one sentence>
RISK: LOW / MEDIUM / HIGH + one sentence
```

Findings are facts and suggestions, **not decisions** — the planner decides what to do with them.
End with `RECON COMPLETE` and a per-axis count of findings.

---

# PHASE 2 — PLAN & DECISION (the team decides)

## Planner spec

Spawn the planner (`general`, `worktree: false`, `claim_task: plan`). Prompt it with:
- All three scout reports (verbatim).
- The LIVE CONTEXT output (verbatim).
- The shared rules at the top of this command.
- The decision protocol below.

The planner reads enough of the underlying files to confirm or reject each finding, then produces
the **refactor plan** — the single authoritative change plan, in two parts:

### 2a. Target branch tree

Propose the target branch tree from the `nix-map` output and the recon findings:

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

### 2b. Numbered task list

Each task must have:
- **What** (one sentence)
- **Why** (cite the recon finding or map reference — e.g. "H4b: users.users.seanc duplicated in 4 host files")
- **Risk** LOW / MEDIUM / HIGH + one sentence
- **Files touched** (list)
- **Depends on** (list of other task IDs, or NONE)
- **Parallel-safe** (yes/no — yes only if it shares no touched files with any other parallel-safe task in the same batch)

### Decision statuses

Every recon finding gets exactly one status in the plan:

| Status | Meaning |
|--------|---------|
| **TASK <n>** | Becomes a numbered task in the task list (with the fields above). |
| **SKIP** | Finding is factually wrong, or the change would be aspirational. Rationale required. |
| **NOTE** | Factually worth recording in the final report, but no task (e.g. needs hardware verification). |

Rules the planner must apply:
- A duplication finding is TASK unless the planner can prove the two sites must diverge.
- Nothing aspirational, nothing speculative — every task must be grounded in code that exists now.
- Tasks that would require guessing at intended behaviour (ambiguous consolidation) → NOTE, never
  force a guess into a task.

## Team decision gate (no human approval)

**The planner's plan is final — the team decides, the human reviews the outcome in the report.**
There is no "wait for the human to approve" step in this command. Safety comes from the per-task
rollback: every task is one dry-activate-verified commit, so a wrong decision is `git revert`-ed,
not pre-empted.

## Lead verification of the plan

You still sanity-check the plan before spawning builders (you own the integration, not the
decisions):

- Verify the planner grounded each task in a real recon finding or map reference — no task may be
  invented from memory.
- Confirm no two parallel-safe tasks share a touched file (the Parallel-safe flag).
- If you disagree with any ruling: verify the disputed finding yourself (re-read the code /
  nix-graph). If you still disagree, record the reversal as **`OVERRIDE`** in the DECISION LOG with
  both positions, and include the override row in the owning builder's prompt. The human sees it in
  the report.
- Then return to Spawn sequence step 3: add the tasks to the board and spawn their builders.

---

# PHASE 3 — EXECUTION (parallel builders)

Spawn the planned builders in parallel (`build`, own worktree, `claim_task`). **Do NOT use
`plan_approval: true`** (see the WARNING in Spawn sequence). Each builder gets: its DECISION LOG
row (the task spec), the shared rules, and the loop below. **Each builder must only touch
its own task's files** — overlapping edits are the one thing that makes parallel refactoring
unsafe (the planner's Parallel-safe flag enforces this).

**MANDATORY worktree note:** a builder's worktree forks at committed HEAD. R-pre guarantees the
main tree is clean, so the worktree is **not** stale — edit directly. (If the tree was somehow
dirtied mid-run, sync first: `cp /home/seanc/nixos-config/<file> <worktree>/<file>` + `diff`.)

For each task, the builder follows this loop:

### Step 0 — Impact analysis (use nix-graph)

Before making changes, understand the blast radius:

```
# Who depends on the module being changed?
nix-graph_get_dependents("modules/nixos/<target>")

# Where is the option being moved/redefined?
nix-graph_get_option_definers("my.<namespace>.<option>")

# Is there a mkForce that would fight the change?
nix-graph_find_mkforce_sites
```

Quote the nix-graph output verbatim in the completion message so the lead can assess risk. No
paraphrasing.

### Step 1 — Show current state

Read and paste the relevant file sections verbatim with path and line numbers.

### Step 2 — Apply the change

Apply the edit exactly as the DECISION LOG row specifies, on the worktree copy. Every added line
gets an explanatory comment (or is pure whitespace). Moved lines retain their comments.

### Step 3 — State the invariant and confirm hard-rule compliance

One sentence: what must remain behaviourally identical after this change.

Then an explicit checklist line:
- [ ] No `meta.nix` `tested` flags touched
- [ ] No `secrets/` or `/run/agenix/` paths touched
- [ ] No `lib.mkForce` added (or: added with comment + a DECISION LOG row exists for it)
- [ ] Every changed line has an explanatory comment, or is pure whitespace/formatting

### Step 4 — Verify in the worktree

Full output is written to a log file; paste the tail plus the log path:

```bash
mkdir -p /tmp/opencode/refine/<task-id>
for host in $(ls configurations/nixos/ | grep -v ventoy-deploy); do
  echo "=== $host ===" | tee -a /tmp/opencode/refine/<task-id>/dry-activate.log
  nixos-rebuild dry-activate --flake ".#$host" --fast \
    > /tmp/opencode/refine/<task-id>/dry-activate-$host.log 2>&1
  tail -20 /tmp/opencode/refine/<task-id>/dry-activate-$host.log
done
```

If the task is eval-only (no host import path) or involves module renames, use
`nix flake check --no-build` instead, plus nix-graph invariants:

```
nix-graph_graph_stats                 # confirm node counts didn't regress
nix-graph_node_info("module:nixos/…") # confirm new module is in the graph
nix-graph_get_dependents("modules/nixos/…")  # confirm dependents resolved correctly
```

If any host errors or nix-graph invariants are broken, revert the change immediately, report the
failure, and do not commit. `ventoy-deploy` is excluded from the dry-activate loop (known OOM
issue).

### Step 5 — Commit in the worktree, then report

Commit the task in your worktree:

```bash
git add -A
git commit -m "refactor(<task-id>): <one-line what> — <recon finding cited in Why>"
```

Then report done via `team_message` with:
- The diff (unified, or full content for new files).
- The commit hash.
- The Step 3 invariant + checklist.
- The dry-activate tail + log path.

The lead merges and re-commits this task's files in the main repo with the same task-scoped
message (see Spawn sequence step 4) — preserving one-task-one-commit in the main history.

---

# PHASE 4 — REVIEW & VERIFY

## Verifier spec

Spawn the verifier (`qa`, `worktree: false`, `claim_task: verify`, **instructed read-only — report
findings, do not edit**). Give it: the DECISION LOG, the merged diff scope, the shared rules, and
the check list below. It must verify **every task was implemented as specified** and report:

- **One task, one commit** — the main-repo history has exactly one commit per task, and `git show
  --stat HEAD~N` file lists match the DECISION LOG rows.
- **Dry-activate passes** across the full host matrix (excluding `ventoy-deploy`).
- **No `meta.nix` `tested` flags touched**, no `secrets/`/`/run/agenix/` paths touched.
- **No `lib.mkForce` added** outside DECISION LOG rows, and every added `mkForce` has a comment.
- **Every changed line has an explanatory comment** or is pure whitespace/formatting.
- **Only the task's owned files changed** per commit; no overlap, no unexpected file types.
- **nix-graph invariants hold** after the refactor (`nix-graph_graph_stats` node counts don't
  regress; renames have their dependents resolved).

The verifier reports `VERIFY PASS` or a list of `VERIFY FAIL` items with file:line. Any FAIL goes
back to the owning builder (message it, re-merge, re-verify) or is fixed directly by you for
trivial issues, recorded in the report.

## Lead's final verification (run yourself before `team_cleanup`)

```bash
git log --oneline -20          # confirm one commit per task, scoped messages
git status --porcelain         # tree clean again at the end
nix fmt -- --check             # formatting enforced by the repo
```

Then, only if the refactor touched evaluation-critical structure, run the full dry-activate matrix
once more yourself:

```bash
for host in $(ls configurations/nixos/ | grep -v ventoy-deploy); do
  nixos-rebuild dry-activate --flake ".#$host" --fast 2>&1 | tail -5
done
```

---

# PHASE 5 — REPORT

Compile the single coherent report for the human — one document, not stitched transcripts. This is
the human's review point: the team made the calls; the human inspects the outcome here.

## 1. Plan summary

A condensed version of the refactor plan showing what was decided and why:

```
PLAN:
- Branch tree: <the target tree actually applied, or "unchanged">
- Tasks: <n> executed, <m> SKIP findings (with reasons), <k> NOTE findings
- Overrides: <n> (list both positions)
```

## 2. Final table

| Task | Files changed | Lines Δ | Risk | Commit hash | Result |
|------|--------------|---------|------|--------------|--------|
| T1   | ...          | -42     | LOW  | abc1234      | ✓      |
| T2   | ...          | +18     | MED  | def5678      | ✓      |

## 3. Rollback

Each task is its own commit, so any task can be reverted independently:

```bash
git revert <task-commit>          # or: git restore --source=HEAD~1 -- <task files>
```

No task commit was reverted during this run unless noted here.

## 4. Out-of-scope & NOTE items

List any refactoring opportunities that were out of scope (too risky, hardware-dependent, or
dependent on earlier tasks completing first), plus every NOTE-status finding and every disruption
that happened during the run.

Each task was already committed individually (Phase 3 Step 5), so no additional commit happens here
— R-final is a report only.

---

# PHASE 6 — SELF-IMPROVEMENT (optional, `SELF_IMPROVE=true`)

> Skip this entire phase when `SELF_IMPROVE=false`. Everything below only runs when the toggle is
> on. Its scope is **this command file only** — it never touches the repo config (those are
> Phases 1-5).

## Why

Every run of this command exercises its own instructions. When an instruction is wrong, stale, or
wasteful (a broken flag, a worktree trap, a merge that silently applies nothing), the next run
repeats the cost. Phase 6 captures those lessons *in the command itself* so each run can optionally
improve the tool that drives it.

## 6.1 Capture run-time lessons (lead, as you go)

During the run, keep a short scratch list of operational facts about **this command's own
execution** — not repo findings. Examples of real lessons (learned 2026-08-03 in nix-doc-audit,
ported here):
- `plan_approval: true` never wakes builders after approval → must re-spawn without the flag.
- Builder worktrees fork at committed HEAD; R-pre keeps the main tree clean, so no sync is needed —
  but if the tree gets dirtied mid-run, builders must `cp` the main-repo file over their worktree
  copy before editing.
- `team_merge` silently applies nothing when a builder only stashed (uncommitted) its work →
  the lead must copy the worktree files into the main repo directly and verify.
- One-task-one-commit requires the lead to re-commit each merged task with a scoped message,
  because the merge lands as unstaged changes.
- No human approval gates: the planner's plan is final and the team proceeds; a wrong task is
  reverted via its own commit, never pre-approved by the human.

Each lesson must be grounded in something that actually happened this run (file:line or a concrete
observed behavior). Do not invent lessons.

## 6.2 Audit this command file (meta-scout)

Spawn **one** read-only scout (`general`, `worktree: false`, `claim_task: self-improve`) whose
only job is to audit `modules/home/opencode/commands/nix-refine.md` against:
- The live run just completed (the run-time lessons from 6.1).
- The actual repo state (do the commands it references exist? are the paths it names current? —
  check against `nix-doc-audit.md` for shared trap documentation).
- Internal consistency (duplicate headings, stale line refs, box-drawing breakage, unbalanced
  code fences, references to files that don't exist).

Give the scout: the run-time lessons, the shared rules at the top of this command, and this
instruction. It reports findings in the FINDING format with `file:line` evidence, ending with
`AUDIT COMPLETE`.

## 6.3 Decide & apply (lead, directly — no builders)

The lead triages the meta-scout's findings with the same TASK / SKIP / NOTE protocol:
- **APPLY** only when the change is grounded in this run's reality (a real failure) or the actual
  current repo (a stale path/command). If it would require guessing, SKIP and NOTE instead.
- Apply edits **directly to this command file** — this is the lead's own tool, no worktree needed.
- Do not add aspirational self-healing ("in future we might..."); only fix what is true now.
- Do not let Phase 6 balloon the file; keep each fix tight and referenced to the lesson.

## 6.4 RUN LOG (append at the bottom of this file)

Record every applied lesson as a dated entry so future runs can read what changed and why. Format:

```
## RUN LOG

### <date> — <one-line title>
- Lesson: <what happened and why the command misled/wasted effort>
- Fix: <what changed in this command file>
```

Append newest at the bottom. Entries are facts about the tool's operation, not repo docs, so they
are exempt from the "only document what exists" rule *for the command file's own machinery* — but
each entry must still describe a real event.

## RUN LOG

### 2026-08-05 — browser-side run OOM-killed the whole web unit; added R-pre memory check + builder waves
- Lesson: Running this command from the opencode **web** session on the server ended with blank
  browser sessions and no sendable messages. The session data was intact — `systemd-oomd`
  (SwapUsedLimit=90%) had killed the *entire* `opencode-web-nix-config.service` cgroup (~4.3G
  memory + 5.8G swap across the team), taking the web server down with it. The module's
  `MemoryHigh`/`MemoryMax` caps bound RAM but not swap, so oomd's whole-unit kill fired first.
- Fix: `modules/nixos/opencode-web/` now sets `MemorySwapMax` (default 4G) and opts units out of
  oomd (`ManagedOOMMemoryPressure`/`ManagedOOMSwap = "never"`) so the kernel OOM-killer removes one
  teammate at a time instead of the web server. Added an R-pre `free -h` memory check and builder
  spawning in waves (≤ 4) on constrained hosts so a full parallel spawn can't spike the cgroup.

### 2026-08-03 — converted from serial human-gated loop to always-team orchestration + self-improvement
- Lesson: The previous command executed one task at a time ("show diff → state invariant → wait for
  'apply' → apply → verify → commit"), which serialized independent tasks and put every decision on
  the human. It mentioned ensemble teammates but only as an optional optimization. It also had no
  mechanism to capture operational lessons about its own execution.
- Fix: Rebuilt around the `nix-doc-audit` orchestration model: an ENSEMBLE GATING section (with a
  single-agent fallback), a recon-scouts → planner → parallel-builders → verifier team shape with a
  task board, and a single human plan-approval gate (plus individual gates for human-gated tasks
  like `mkForce`). Added the SELF_IMPROVE toggle, Phase 6, and this RUN LOG. Ported the
  `plan_approval: true`, `depends_on` label, and merge-pitfall lessons from `nix-doc-audit`.

### 2026-08-03 — removed all human approval gates; the team decides, rollback is the safety net
- Lesson: The first pass kept a human plan-approval gate (plus per-task gates for `mkForce`/HIGH
  risk). That still serialized the run on a human turn and implied changes were unsafe without
  pre-approval — when every task is one dry-activate-verified, independently-revertible commit,
  `git revert <task-commit>` is the failure path and no human sign-off is needed up front.
- Fix: Removed the Phase 2 human approval gate and the per-task "Human gate" flag. The planner's
  DECISION LOG is now final; the lead's only role is a sanity cross-check with `OVERRIDE` recording
  (mirroring `nix-doc-audit`'s disagreement protocol). Added a rollback callout in the intro, a
  per-task-commit rollback section in Phase 5, and reworded all approval-gate references to team
  decision-making. `mkForce` now requires a comment + DECISION LOG row instead of human approval.

# END OF COMMAND
