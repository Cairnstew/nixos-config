---
description: Audit and update all documentation in the repo so future agents have accurate, complete context. Optionally improves itself after each run (SELF_IMPROVE).
---

You are the **lead** of a documentation-audit team for a NixOS flake-parts repository.
You orchestrate a team of parallel agents via the opencode-ensemble plugin; you do not do the
section work yourself. **The team — not the human — decides which changes to make.** Workload is
split between agents along natural doc boundaries, then re-integrated by you with a verification
gate.

Load and follow the `opencode-ensemble` and `nixos-ensemble-decomposition` skills for the lead
workflow before starting.

**Non-negotiable rules (apply to every teammate, every phase):**
- The team reads the **actual current state of the code** and updates every doc file to match it.
- **Never update docs from memory. Every doc change must be grounded in a file a teammate read this session.**
- **Do not add aspirational or speculative content — only document what exists.**
- **Docs use plain relative markdown links only — never wikilinks (`[[...]]`). GitHub must render every link with no plugin.**

---

## ENSEMBLE GATING

Detect whether the team tools are actually present in this session (config can list the plugin
but it may not have loaded):

- If tools named `team_create`, `team_spawn`, `team_tasks_add`, `team_status`, `team_results`,
  `team_merge`, `team_shutdown`, `team_cleanup` are available to you right now → **`ENSEMBLE_ACTIVE=true`**.
- Otherwise → **`ENSEMBLE_ACTIVE=false`**, regardless of config.

- **If `ENSEMBLE_ACTIVE=true`** — run the team orchestration in this command exactly.
- **If `ENSEMBLE_ACTIVE=false`** — run a single-agent fallback: you play every role (scout ×5,
  arbiter, builder ×4, verifier) in order, applying the **same** decision protocol. The team
  decision rules still replace the human confirmation gates; the "confirm with the human" steps
  in this file are never taken.

---

## SELF-IMPROVEMENT TOGGLE

This command can optionally **improve itself** after each run. When enabled, Phase 6 audits THIS
command file (`modules/home/opencode/commands/nix-doc-audit.md`) — the tool — against what actually
happened during the run and updates it, so the next run is smoother.

- Set **`SELF_IMPROVE=true`** (edit the line below) to enable Phase 6.
- **`SELF_IMPROVE=false`** (default) skips Phase 6 entirely — Phases 1-5 (audit → update → report)
  still run unchanged.

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

The `nix-graph` MCP server provides ground-truth structural data from the v1 scope.
Use it to cross-reference documentation claims:

| Tool | Audit use case |
|------|---------------|
| `nix-graph_graph_stats` | Ground truth for module/host/option counts claimed in docs |
| `nix-graph_search_nodes(query)` | Discover modules, hosts, options the graph knows about |
| `nix-graph_node_info(node_id)` | Get metadata for a specific module to verify doc claims |
| `nix-graph_get_dependents(module_path)` | Verify import relationships claimed in docs |
| `nix-graph_get_option_definers(option_path)` | Check option declaration sites match what docs say |
| `nix-graph_find_namespace_violations` | Cross-reference with GOTCHAS.md entries |
| `nix-graph_find_mkforce_sites` | Cross-reference with GOTCHAS.md entries |

**Known limitation (confirmed 2026-08-03):** `get_dependents` matches by path substring, not exact
path. Querying `modules/nixos/tailscale` also returns `modules/nixos/tailscale-watchdog` — a
sibling, not a dependent. Any use of `get_dependents` output in a doc claim or generated sidecar
must filter to exact path-segment matches before being written anywhere.

Also known (confirmed 2026-08-03): `nix-graph_node_info` matches by suffix, so querying
`module:nixos/tailscale` returns the `.default` sub-node, not a directory-level node. Don't assume
`node_info` on a bare module path returns a single canonical node — check which sub-node came back
before using its fields in a doc claim.

Also known: `graph.json` does not currently carry `expects`/`provides`/`tags` from each module's
`meta.nix` (53 modules declare `expects`, 83 declare `provides`; none of it is in the graph as of
2026-08-03). Do not read `meta.nix` `expects`/`provides` directly as a workaround to fill this gap
— that's a separate nix-graph data-model enhancement, out of scope here. Note it as a limitation
where relevant, don't route around it.

---

## LIVE CONTEXT (lead gathers before spawning)

Run these yourself before creating the team. Hand the output to every scout so they don't
rediscover it. This is the shared baseline; scouts must build on it, not repeat it.

Start with the nix-graph structural overview:

```
nix-graph_graph_stats
nix-graph_search_nodes("module:nixos/")
nix-graph_search_nodes("module:home/")
nix-graph_search_nodes("host:")
nix-graph_find_namespace_violations
nix-graph_find_mkforce_sites
```

**Before spawning anything, check the working-tree state (confirmed critical 2026-08-03):**
```
git status --short
```
If the working tree is **dirty** (uncommitted `.md` changes — this repo frequently has them), then:
- Those dirty files **ARE the current audit target**. They are NOT a mess to be reverted; a prior pass
  may have already improved them. Scouts must read the **main-repo files at `/home/seanc/nixos-config/<path>`**
  (or the equivalent CWD for whatever checkout you launched from), NOT whatever a freshly-created
  teammate worktree shows — a worktree is forked at committed HEAD and will be **stale**.
- Record in LIVE CONTEXT: the list of dirty files (`git status --short` output). Hand this to every scout
  and builder so nobody audits/edits the committed-HEAD version by accident.
- Builders MUST physically sync (`cp` main-repo file over worktree file + verify `diff` identical) before
  editing, or their merge will clobber the dirty state. See the builder rules in Phase 3.
- The lead must reconcile scout findings against the dirty files before handing them to the arbiter
  (a scout that read committed HEAD will report false STALE/MISSING items, e.g. "mkForce site undocumented"
  when the dirty GOTCHAS.md already documents it — this happened 2026-08-03 and cost a full arbiter pass).

Then supplement with shell exploration for data outside the v1 scope:

Repo structure snapshot:
!`find . -not -path './.git/*' -not -path './secrets/*' -not -name '*.lock' -not -path './templates/*' -not -path './packages/localsend/pubspec*' | sort`

Active hosts:
!`ls configurations/nixos/`

Module list (nixos):
!`ls modules/nixos/`

Module list (home):
!`ls modules/home/`

Flake inputs:
!`grep -E '^\s+[a-zA-Z_-]+\.(url|follows)' flake.nix`

Current GOTCHAS.md:
!`cat GOTCHAS.md`

Current STRUCTURE.md:
!`cat STRUCTURE.md`

Current README.md:
!`cat README.md`

All cross-file relative markdown links currently in the repo:
!`rg -o '\]\(\.\.?/[^)]+\)' --glob '*.md' --glob '!**/node_modules/**' --glob '!**/.git/**' --glob '!templates/**' .`

**Known glob gotcha (confirmed 2026-08-03):** `--glob '!./templates/**'` (with the `./` prefix)
does NOT exclude templates in `rg` — it silently matches 0 files, letting 3+ spurious template
links leak into the results. The exclusion glob must be `!templates/**`, no `./` prefix. If this
extraction is ever copy-pasted elsewhere, keep the prefix off.

---

# TEAM ORCHESTRATION

## Why a team

The audit covers 8 independent doc surfaces (A1–A8) that can be mapped in parallel, and the update
touches 4 non-overlapping file groups. A single agent serializes all of it and makes every call
alone; a team maps the repo faster and, critically, **replaces the human confirmation gate with a
team decision gate** — findings are triaged by an arbiter, decided by the team, and the human only
reviews the outcome.

## Team shape

| Role | Agent | Worktree | Ownership |
|------|-------|----------|-----------|
| Audit scout ×5 | `general` | `false` | One A-section group each (see below) |
| Arbiter (triage/decision) | `general` | `false` | Synthesizes scout findings → DECISION LOG |
| Builder ×4 | `build` | `true` | One file group each (strict, non-overlapping) |
| Verifier | `qa` | `false` | Post-merge review + mechanical checks |

> **Why `general` instead of the configured `scout`/`reviewer` subagents:** the audit sections are
> shell-heavy (`grep`, `rg`, `find`, `test`) and the config.nix subagents `scout` and `reviewer`
> are declared `bash = "deny"`. Spawn audit/triage teammates as `general` with an explicit
> **read-only, report-only** instruction. If those subagents are later granted bash, swap the role
> names in — the task spec below is unchanged.

## Task board

Create the team (`team_create` — name it `nix-doc-audit`), then record every task up front with
`team_tasks_add`. **Use the returned IDs** for `depends_on` — do not invent IDs.

> **`depends_on` label trap (confirmed 2026-08-03):** the `Task key` column below is a label for
> humans only. Real task IDs come from `team_tasks_add`'s return (format `task_<rand>_<n>`). Passing
> the labels as `depends_on` values creates a phantom dependency that never resolves — the downstream
> task shows permanently `[blocked] by unresolved dependencies` and no builder can claim it (this
> happened for all four build tasks in the 2026-08-03 run). If that happens, tell the builders to
> proceed **without claiming** (their DECISION LOG rows are embedded in their prompts) and use
> `team_tasks_complete` on the build tasks once their builders are done so the board unblocks the
> verifier. The table is illustrative; treat the returned IDs as authoritative.

| Task key (label) | Description | depends_on (real IDs) |
|----------|-------------|------------|
| `audit-struct-readme` | Scout: A1 STRUCTURE.md + A2 README.md audit (read-only) | — |
| `audit-modules` | Scout: A3 module READMEs + A8 sidecars audit (read-only) | — |
| `audit-gotchas` | Scout: A4 GOTCHAS.md audit (read-only) | — |
| `audit-skills` | Scout: A5 opencode skills + A6 AGENTS.md audit (read-only) | — |
| `audit-links` | Scout: A7 cross-doc link integrity audit (read-only) | — |
| `triage` | Arbiter: synthesize all scout findings into the DECISION LOG | all five `audit-*` |
| `build-struct-readme` | Builder: apply APPLY items to STRUCTURE.md + README.md | `triage` |
| `build-modules` | Builder: apply APPLY items to module READMEs + Related Modules sidecars | `triage` |
| `build-skills` | Builder: apply APPLY items to opencode skills + AGENTS.md | `triage` |
| `build-gotchas` | Builder: apply APPLY items to GOTCHAS.md (always last) | `triage`, all three `build-*` |
| `verify` | Verifier: review merged diff + run mechanical checks | all four `build-*` |
| `report` | Lead: compile decision log + summary table, deliver | `verify` |
| `self-improve` | Meta-scout: audit this command file (Phase 6, only when `SELF_IMPROVE=true`) | — |

## Spawn sequence & merge order

1. `team_create`, `team_tasks_add` (board above), then **spawn the five scouts in parallel**,
   `worktree: false`, `claim_task` their audit task. Give each the LIVE CONTEXT output plus the
   full text of its A-section(s) below as the prompt. **Tell every scout explicitly to read files
   from the main repo checkout (e.g. `/home/seanc/nixos-config/<path>`), not a worktree copy** —
   worktrees fork at committed HEAD and are stale when the working tree is dirty.
2. Wait for all scouts via `team_results`. **Reconcile scout findings against the dirty files
   yourself before composing the arbiter prompt** (see the LIVE CONTEXT working-tree check): any
   finding that quotes content that differs between committed HEAD and the dirty file must be
   re-verified against the dirty file. Compose the arbiter prompt from the reconciled findings
   (verbatim quotes) and spawn the arbiter (`general`, `worktree: false`, `claim_task: triage`).
3. Review the DECISION LOG. If you disagree with any ruling, message the arbiter to reconsider
   (see Decision protocol). Once settled, spawn B1–B3 builders in parallel
   (`build`, own worktree, `claim_task` their build task). **Do NOT use `plan_approval: true`** —
   see the warning below. Each builder gets: its file group, the DECISION LOG APPLY items for that
   group, the applicable update rules + template from Phase 3 below, and the mandatory sync step.
4. As each builder reports done: `team_results`, `team_shutdown`, `team_merge`. **Inspect the
   merged diff before trusting it** — confirm the dirty current content survived (compare the
   merged file against the pre-edit dirty state + the DECISION LOG rows, not against committed HEAD).
   **Dirty-tree merge refusal (confirmed 2026-08-03 — happens on EVERY builder merge when the main
   tree is dirty):** `team_merge` returns `Cannot merge <name> — you have local changes to the same
   files: ...` for every target file that is dirty in the main checkout (which is the whole point —
   those dirty files ARE the audit target). This is the PRIMARY merge path for a dirty tree, not an
   edge case. Recovery: the builder's branch is preserved at
   `ensemble/preserved/<team>#<run>/<builder>` and its committed version of each file equals
   "dirty baseline + intended edits" (the builder synced the dirty file before editing). Restore it:
   ```
   git diff "<preserved-branch>" -- <files>   # must show ONLY the intended edits
   git restore --source="<preserved-branch>" --worktree -- <files>
   git diff "<preserved-branch>" -- <files>   # must now be empty
   ```
   then spot-check the distinctive strings from the DECISION LOG rows. If instead `team_merge`
   **applies nothing** (confirmed 2026-08-03: builders that only stash uncommitted changes produce
   an empty merge — `team_merge` has no commit to bring in), then the builder's work sits in its
   worktree; copy the files directly: `cp <worktree>/<file> /home/seanc/nixos-config/<file>` after
   verifying the worktree diff shows exactly the intended edits. **Before spawning each builder,
   cross-check every `OVERRIDE` row for that builder's group is present in its prompt** (the 2026-08-03
   run omitted the M11 override row from b-modules' prompt, requiring a post-verifier manual fix).
   Update the task board (`team_tasks_complete` on the build task — also unblocks downstream tasks
   caught in the label trap) and record the manual-apply in the report.
5. After B1–B3 are merged, spawn B4 (`build-gotchas`, `build`, `claim_task`) so it forks
   from the merged state — GOTCHAS RESOLVED markers cite fixes made by the other builders.
   Merge it the same way.
6. Spawn the verifier (`qa`, `worktree: false`, `claim_task: verify`). If it finds issues, message
   the owning builder (still alive) to fix, re-merge, re-verify. Minor issues you may fix directly,
   recording that in the report.
7. Run the final verification yourself (Phase 4 commands) before `team_cleanup`.

> **WARNING — `plan_approval: true` is broken (confirmed 2026-08-03).** A builder spawned with
> `plan_approval: true` sends its plan then **ends its run-cycle**; the lead's `team_message`
> `approve: true` response is stored but **never wakes it** (the tool returns "teammate has
> completed their task — message will not wake them"). The builder idles forever with zero edits.
> Do not use `plan_approval: true` in this command. The DECISION LOG IS the approval: the arbiter
> already decided the exact changes, so embed the APPLY rows directly in the builder prompt. If a
> builder is spawned with `plan_approval: true` anyway (e.g. pasted from an older version), the fix
> is `team_shutdown --force` + re-spawn without the flag, embedding the approved plan as the task.

If any teammate stalls or errs: message it directly first; `team_shutdown --force` only as a last
resort; record the disruption in the final report.

---

# PHASE 1 — AUDIT (parallel scouts)

Spawn five scouts in parallel. **Each is read-only — it must not edit or write anything.** Each
must return findings in the STALE / MISSING format below, with `file:line` evidence and verbatim
quotes. Scouts report via `team_message`.

Give each scout: the LIVE CONTEXT output, the shared rules at the top of this command, and the full
text of its A-section(s) from below as its prompt.

## Scout assignment

| Scout | Task | Sections | Focus |
|-------|------|----------|-------|
| `s-struct-readme` | `audit-struct-readme` | A1 + A2 | STRUCTURE.md, README.md |
| `s-modules` | `audit-modules` | A3 + A8 | module READMEs, Related Modules sidecars |
| `s-gotchas` | `audit-gotchas` | A4 | GOTCHAS.md |
| `s-skills` | `audit-skills` | A5 + A6 | opencode skills, AGENTS.md |
| `s-links` | `audit-links` | A7 | cross-doc links, wikilinks |

---

## A1. STRUCTURE.md audit (s-struct-readme)

Read `STRUCTURE.md`. Then verify each claim it makes by reading the referenced files/paths.
For every claim that is wrong, missing, or stale, note:
```
STALE: "<quoted claim from STRUCTURE.md>"
ACTUAL: <what the code actually shows, with file:line>
```
For every directory or pattern the code has that STRUCTURE.md does not mention:
```
MISSING: <path or pattern>
ACTUAL:  <what it is and why an agent needs to know it>
```

## A2. README.md audit (s-struct-readme)

Read `README.md`. Verify:
- Every command listed actually exists in the `justfile` or as a script:
  !`cat justfile`
- Every module or feature mentioned exists at the stated path.
- The host list matches `configurations/nixos/`.
- Installation/bootstrap steps reference files that exist.

Flag discrepancies in the same STALE / MISSING format.

## A3. Module README.md audit (s-modules)

Use nix-graph to discover modules and their declared options:

```
# Find all modules in the graph to cross-reference with filesystem
nix-graph_search_nodes("module:nixos/")
nix-graph_search_nodes("module:home/")

# For each module with a README, check option declarations match docs:
nix-graph_node_info("module:nixos/tailscale")
nix-graph_get_option_definers("my.services.tailscale.enable")
```

For every directory under `modules/nixos/` and `modules/home/` that contains a `README.md`, check:
- Does the README describe the options that actually exist in `options.nix`?
- Does it list the correct `my.<namespace>.*` option paths?
- Does it mention dependencies (other modules, flake inputs) that are still accurate?
- Is the example config in the README syntactically valid and consistent with current options?
- Does it have a `## Related Modules (generated — do not hand-edit)` block, and if so, does it
  match what a fresh `nix-graph` query returns right now? (See A8 for the generation rules —
  do not eyeball this by reading imports yourself; use the same exact-match-filtered query.)

Read each `options.nix` and its paired `README.md`. Report:
```
MODULE: modules/nixos/<name>/
  STALE: <quoted README claim>
  ACTUAL: <what options.nix actually declares, with line>

  MISSING from README:
  - <option or behaviour an agent would need to know>
```

For modules that have **no README.md** but have non-trivial options (more than just `enable`), use
nix-graph to cross-reference their declared options:
```
nix-graph_search_nodes("module:nixos/<name>")
nix-graph_node_info("module:nixos/<name>")  # if available in graph
```
List them as:
```
NO README: modules/nixos/<name>/  (options: my.foo.bar, my.foo.baz)
```

## A4. GOTCHAS.md audit (s-gotchas)

Use nix-graph to validate structural gotchas:

```
# Check if mkForce sites are properly documented in GOTCHAS.md
nix-graph_find_mkforce_sites

# Check if namespace violations are properly documented
nix-graph_find_namespace_violations

# Check namespace violation counts against GOTCHAS.md claims
nix-graph_graph_stats
```

Read `GOTCHAS.md`. For each entry:
- Is the gotcha still present in the code? (grep for the relevant pattern; use nix-graph for structural ones)
- If it was fixed and the fix is now the standard approach, mark it as RESOLVED.
- If it is still a live trap, verify the workaround is still accurate.

Then scan the codebase for patterns that should be gotchas but aren't documented:

```bash
grep -rn 'mkForce\|# FIXME\|# HACK\|# TODO\|# WORKAROUND\|# NOTE:' \
  modules/ configurations/ \
  --include='*.nix' | grep -v '.git'
```

Paste the output. For each hit, decide if it warrants a GOTCHAS.md entry. **Do not decide alone —
flag candidates for the arbiter** with a proposed entry (symptom → cause → fix).

Cross-reference with nix-graph: if `find_mkforce_sites` returns sites not mentioned in GOTCHAS.md,
flag them as MISSING. Similarly for `find_namespace_violations`.

Also check for the known structural traps from previous analysis:
- `lib.mkIf` scoping (attribute-level vs attrset wrapping)
- `$'\n'` in Nix strings
- `builtins.path` referencing `/run/agenix/` at eval time
- disko + dual-boot `mkIf false` additive merge behaviour
- msmtp `--passwordeval` as CLI flag vs config directive
- Shell scripts expanding systemd specifiers (`%i`)

For each: verify whether it is documented in GOTCHAS.md. If not, flag as MISSING.

**Also check the file's own internal consistency**, since this has drifted before:
- Is there more than one `## Format` (or any other) heading appearing twice? Flag it, don't
  silently pick one — the arbiter decides how to merge duplicate headings (see Decision protocol).
- Does `## Adding New Entries` (or equivalent) still say what this command's P-final section
  assumes it says? If GOTCHAS.md's own stated convention has changed since this command was last
  updated, flag the mismatch instead of proceeding on a stale assumption.
- Are entries dated? If some are and some aren't, note the count of undated entries — the arbiter
  decides whether/how to backfill dates (see Decision protocol).

## A5. opencode skills audit (s-skills)

Read every file under `modules/home/opencode/skills/`.
For each skill file, verify:
- Does it reference module paths that still exist?
- Does it reference commands/options/patterns that match current code?
- Does it reference hosts or profiles that still exist?
- Is there a skill that is missing entirely for a significant workflow?

Check for missing skills by looking at what the repo actually does:
!`ls modules/home/opencode/skills/`

Known workflows that should have skills (verify each exists and is accurate):
- `deploy-workflow.md` — nixos-anywhere + nixos-rebuild boot flow
- `module-development.md` — options/config/meta/tests/default pattern
- `secrets-management.md` — agenix-manager two-layer trust chain
- `testing-patterns.md` — VM-first test approach
- `nixos-configuration.md` — host assembly pipeline

Flag gaps and stale content in the same STALE / MISSING format.

## A6. AGENTS.md audit (s-skills)

Read `AGENTS.md` and `configurations/AGENT.md` and `modules/AGENT.md`.
Verify each instruction is accurate given the current code structure.
Flag anything that would mislead an agent (stale paths, wrong module names, outdated patterns).

## A7. Cross-doc link integrity audit (s-links)

Using the link list already extracted in LIVE CONTEXT (`rg -o '\]\(\.\.?/[^)]+\)' ...`):

For each relative link found, resolve it against its source file's directory and check existence:
```bash
test -f "$(dirname "$SOURCE_FILE")/$TARGET"
```
Report PASS/FAIL per link with total counts. Any FAIL means either the link text is wrong or the
target moved — **do not guess the intended fix**; report it as a MISSING/STALE item for the arbiter
to decide (see Decision protocol: the team resolves it with a confirmed real target via
`find`/`grep`, not an assumed one).

Confirm no `[[wikilink]]` syntax has been introduced anywhere:
```bash
rg -n '\[\[.*\]\]' --glob '*.md' --glob '!**/node_modules/**' --glob '!**/.git/**' .
```
If any are found, flag them — they render as plain text on GitHub and must be converted to
relative markdown links, not left as-is.

## A8. Related Modules sidecar audit (s-modules)

For each module README that has (or should have) a `## Related Modules (generated — do not
hand-edit)` block:

1. Re-run `nix-graph_get_dependents(module_path)` and `nix-graph_get_option_definers(option_path)`
   for that module now.
2. **Filter to exact path-segment matches only** — split the returned path on `/` and compare
   the full module path component-by-component against the target; do not accept a substring
   match (see the tailscale/tailscale-watchdog case in the tools table above).
3. **Drop internal-file edges** — a module's own `default.nix → {options,config,tests,meta}.nix`
   imports are not "related modules," exclude any edge where source and target share the same
   module root directory.
4. Compare the filtered, current result against what the README's existing sidecar block (if any)
   claims. Flag as STALE any sidecar whose content doesn't match a fresh, filtered query — sidecars
   go stale exactly like prose does and get no special exemption from this audit.
5. **Scope guard, required before emitting a "no dependents" claim (confirmed 2026-08-03):** an
   empty `get_dependents` result does not by itself mean the module has no dependents — it may
   mean the module isn't in the graph at all. Before rendering "no dependents," confirm the module
   path has **at least one node** in `graph.json`:
   ```bash
   jq --arg m "modules/nixos/<name>" \
     '[.nodes[] | select(.id == $m or (.id | startswith("module:" + ($m | ltrimstr("modules/")))))] | length' \
     tools/nix-graph/graph.json
   ```
   **Do not use `ltrimstr("modules/nixos/")`** — node ids are `module:` + the path *after*
   `modules/` (e.g. `module:nixos/tailscale.default`), not after `modules/nixos/`. The
   `modules/nixos/`-stripping variant returns 0 for every module, silently misclassifying all of
   them as "not tracked." This was caught in the 2026-08-03 Phase 1 run — verify the corrected
   query returns non-zero for tailscale (7), suwayomi (1), and common (1), and zero for proxy,
   before trusting its output for any module. Or equivalent `nix-graph_search_nodes` /
   `nix-graph_node_info` check that matches on the same `module:nixos/<name>` prefix convention.
   Concrete proof this matters: `modules/nixos/proxy` is imported by `common.nix:47` in the actual
   code, but has zero nodes in `graph.json` (it's outside the extractor's v1 scope) — a naive
   empty-result check would render "No other modules currently import this one," which is
   factually false.
   - If the module **has** graph nodes and the dependents query is genuinely empty: render
     `No other modules currently import this one.`
   - If the module has **zero** graph nodes at all: render
     `Not currently tracked by nix-graph (outside v1 extraction scope) — dependents cannot be
     verified from graph data. Do not infer from reading imports manually; report as unverifiable.`
     Do not silently fall back to manually grepping imports as a substitute — that reintroduces
     exactly the hand-maintained, drift-prone linking this sidecar exists to avoid.
6. Modules with a sidecar showing zero dependents and zero externally-referenced options, **and**
   confirmed present in the graph per rule 5, should say so explicitly
   (`No other modules currently import this one.`) — an absent section reads as "not checked," a
   present empty one reads as "checked, found nothing." Flag any sidecar that omits the section
   entirely instead of stating this.

---

## Scout output contract

Each scout ends its report with `AUDIT COMPLETE` and a per-section count of STALE / MISSING
findings. **Findings are facts, not decisions** — the arbiter decides what to do with them.

---

# PHASE 2 — TRIAGE & DECISION (the team decides)

**This replaces the old "wait for the human to confirm before Phase 2" gate.** The team makes the
call. The human reviews the outcome at the end, not each step.

## Arbiter spec

Spawn the arbiter (`general`, `worktree: false`, `claim_task: triage`). Prompt it with:
- All five scout reports (verbatim).
- The shared rules at the top of this command.
- The decision protocol below.

The arbiter reads enough of the underlying files to confirm or reject each finding, then produces
the **DECISION LOG** — the single authoritative change plan. No file is touched without a DECISION
LOG row.

## Decision statuses

Every finding gets exactly one status:

| Status | Meaning |
|--------|---------|
| **APPLY** | A builder will change the doc to match the code (with the exact edit specified). |
| **SKIP** | Finding is factually wrong, or the doc is intentionally not-literal (e.g. an example), or the "fix" would be aspirational. Rationale required. |
| **NOTE** | Factually worth recording in the final report for the human, but no doc change (e.g. out-of-scope, needs hardware verification). |

Rules the arbiter must apply:
- A STALE finding is APPLY unless the arbiter can prove the code claim is wrong.
- A MISSING finding is APPLY only if the missing thing is real, stable, and agent-relevant.
  Nothing aspirational, nothing speculative, nothing the code doesn't actually do.
- A finding whose fix would require guessing a target the code can't confirm → resolve it per the
  protocol below, never APPLY a guessed value.

## Decision rules for previously-human-flagged items

The old command deferred these to the human. **The team now decides each, with the decision
recorded in the log:**

1. **Duplicate GOTCHAS headings** (e.g. two `## Format` sections): the arbiter decides how to
   merge — keep the fullest content, fold the other's unique points into it, and note the merge in
   the DECISION LOG. The arbiter reads both sections and produces the merged text; the builder
   applies it. (If the two genuinely conflict and only a human could choose, still decide: pick
   the one that matches the actual code, and flag the discarded variant in the report.)
2. **Undated GOTCHAS entries**: the arbiter attempts to date them from git history
   (`git log --follow -1 --format=%cs -- <path-to-insertion>` for the commit that introduced each
   entry, or `git blame`). If a reliable date exists, APPLY the backfill **and record provenance**
   ("date from git history commit <sha>"). If history is ambiguous, SKIP backfill and NOTE it.
3. **Unconfirmable broken links (A7 FAIL)**: the arbiter instructs the owning builder to search
   for the real target (`find`/`grep` for the linked concept). If a unique target exists → APPLY
   the confirmed link. If multiple plausible targets → pick the canonical one (module root,
   not internal file) and note the choice. If **no** target exists → APPLY removal or a repoint to
   the closest existing doc, with the reasoning in the log. Never leave a known-broken link
   unaddressed; never guess a path that isn't confirmed to exist.
4. **GOTCHAS.md internal-convention drift** (its `## Adding New Entries` no longer matches what
   the P-final section assumes): follow the file's current wording — the file is canonical — and
   add a NOTE when this command's own P-final text needs updating to match.

## Disagreement protocol

- If you (the lead) disagree with any arbiter ruling: message the arbiter, present your evidence,
  and ask it to reconsider with a specific counter-argument.
- **But a completed arbiter can't be woken** (confirmed 2026-08-03 — same "message will not wake
  them" limitation as the `plan_approval` builders): if the arbiter already sent its DECISION LOG
  and ended its run-cycle, your `team_message` is stored but never delivered. The effective path is
  then your call wins as lead, **recorded as `OVERRIDE` in the DECISION LOG** with both positions
  (see below), and the OVERRIDE row must be included in the owning builder's prompt (see Spawn
  sequence step 4). The human sees it in the report. Verify the disputed finding yourself before
  overriding — the 2026-08-03 arbiter's M11 ruling rested on a faulty grep (claimed 0 matches for a
  pattern that actually matched 5 times).
- If the arbiter changes the ruling → update the DECISION LOG.
- If it holds its ground and you still disagree → your call wins as lead, but it is **recorded**
  as `OVERRIDE` in the DECISION LOG with both positions. The human sees it in the report.

## DECISION LOG format

```
## DECISION LOG (authoritative change plan)
| # | Finding (file + quote) | Status | Decision / exact change | Owner |
|---|------------------------|--------|-------------------------|-------|
| 1 | STRUCTURE.md: "...stale..." | APPLY | Rewrite to: <exact new text> | build-struct-readme |
| 2 | GOTCHAS.md: duplicate ## Format | APPLY | Merge per arbiter: <merged text> | build-gotchas |
| 3 | README.md: "...planned..." | SKIP | Aspirational, doc is intentionally forward-looking | build-struct-readme |
...
```

No row with status APPLY may lack: (a) the exact change to make, or (b) the owning builder.
The builders implement **only** APPLY rows for their group.

---

# PHASE 3 — UPDATE (parallel builders)

Spawn B1–B3 in parallel (`build`, own worktree, `claim_task`). **Do NOT use `plan_approval: true`**
(see the WARNING in Spawn sequence). Each builder gets: its file group, the DECISION LOG APPLY rows
for that group, the shared rules, the mandatory sync step below, and the rules below. After merging
B1–B3, spawn B4. **Each builder must only touch its own files** — overlapping edits are the one
thing that makes parallel updates unsafe.

| Builder | Task | Owned files |
|---------|------|-------------|
| `b-struct-readme` | `build-struct-readme` | `STRUCTURE.md`, `README.md` |
| `b-modules` | `build-modules` | `modules/nixos/*/README.md`, `modules/home/*/README.md` (create/update) |
| `b-skills` | `build-skills` | `modules/home/opencode/skills/*.md`, `AGENTS.md`, `configurations/AGENT.md`, `modules/AGENT.md` |
| `b-gotchas` | `build-gotchas` | `GOTCHAS.md` only (spawned last) |

> **Ownership carve-outs (resolve before spawning):** when the arbiter assigns a file to a builder
> that is also covered by another builder's generic glob (e.g. `modules/home/opencode/README.md`
> is both a `modules/home/*/README.md` and a skill-ecosystem file), state the carve-out in BOTH
> builder prompts so only one edits it. Verify no two builders list the same path. Known carve-out
> (2026-08-03 run): `modules/home/opencode/README.md` + `modules/home/opencode/AGENT.md` were
> assigned to `b-skills` (opencode-skill-ecosystem rows), NOT `b-modules`, even though they match
> `modules/home/*/README.md`.

**MANDATORY sync step for every builder (dirty-working-tree protection):**
A builder's worktree is forked at committed HEAD. If the main working tree is dirty (uncommitted
`.md` changes — the audit target), the worktree copies are **stale** and editing them would make
`team_merge` clobber the current state. Before editing ANY owned file:
1. `git rev-parse --show-toplevel` — if your top-level is NOT the main checkout (e.g.
   `/home/seanc/nixos-config`), you are in a stale worktree.
2. For each file you will edit: `cp /home/seanc/nixos-config/<file> <your-cwd>/<file>` (or the
   equivalent path for your checkout), then `diff` to confirm identical.
3. Apply your DECISION LOG edits **on the synced content**. Never base edits on the worktree's
   committed-HEAD copy.
4. Post-edit, confirm the pre-existing dirty content survived (diff your final file against the
   pre-edit dirty state + your intended changes only).

**Builders must confirm the change is still true at write time** — re-read the source file
(`options.nix`, `config.nix`, etc.) immediately before writing, then apply the DECISION LOG edit.
If the code has moved, report back rather than writing stale content.

### Rules for every builder update

**For existing files:**
- Show a unified diff for every change in your completion message (the DECISION LOG already specifies
  each change, so no separate plan gate is needed; the lead reviews the completion diff).
- Do not delete content unless it is factually wrong — prefer adding an "as of <date>" note or a RESOLVED marker.
- Do not add aspirational sections ("future work", "planned features") unless they already exist in the file.
- Any link fix must use a target confirmed to exist by `find`/`grep` in this session — never a guessed path.
- Any `## Related Modules` block written or refreshed must be produced by the exact-match-filtered,
  internal-edge-dropped query described in A8 — never hand-written or inferred by reading the
  module's config yourself.
- After writing, verify the write succeeded and re-run the A7/A8 checks against your own written
  content before reporting done (confirm you introduced no new broken link or stale sidecar).

**For new README.md files (missing module docs):**
Use this template and fill every section from the actual `options.nix` and `config.nix`:

```markdown
# <module-name>

<One sentence describing what this module does.>

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `my.<namespace>.enable` | bool | false | Enable this module |
| `my.<namespace>.<option>` | <type> | <default> | <description> |

## Usage

\`\`\`nix
# In your host default.nix or a profile:
my.<namespace> = {
  enable = true;
  # ... other options
};
\`\`\`

## Dependencies

- **NixOS modules**: <list any modules this imports, as relative markdown links where a README exists>
- **Flake inputs**: <list any inputs used>
- **Home-manager peer**: <path if exists, else NONE>

## Related Modules (generated — do not hand-edit)

> Auto-generated from `tools/nix-graph/graph.json` on <date>. Do not edit this block by hand —
> re-run `/nix-doc-audit` to refresh it.

- Depended on by: <exact-match-filtered list>, OR if the dependents query is empty **and** the
  module has ≥1 node in graph.json: "No other modules currently import this one.", OR if the
  module has **zero** nodes in graph.json: "Not currently tracked by nix-graph (outside v1
  extraction scope) — dependents cannot be verified from graph data." **Never render the
  "no other modules" line without first confirming the module has graph nodes** — see A8 rule 5.
- Options defined here: <DEFINES edges for this module, or "Not currently tracked by nix-graph"
  under the same condition>

## Notes

<Any non-obvious behaviour, ordering requirements, or known issues.>
```

---

## B4 / P-final. GOTCHAS.md — always last

GOTCHAS.md's own `## Adding New Entries` section is canonical — the builder follows it, not this
command's wording. As of 2026-08-03 that section specifies: new entries go to the **top** of the
file (newest first), format is symptom → cause → fix, one paragraph, with the specific error
message or symptom pattern included. If the audit found the file's own convention has changed,
follow the file's current wording.

The `b-gotchas` builder applies, in order:
- **New entries:** insert at the top of the file, immediately after any header/format preamble,
  above all existing entries. Do not append to the bottom.
- **Resolved entries:** do not delete or rewrite the original entry. Add a line directly beneath
  it: `> **RESOLVED** — <date> — <how it was resolved>`. The original symptom/cause/fix text stays
  intact so the historical record isn't lost.
- **Superseded entries** (the decision changed, not just "fixed"): same pattern, `> Superseded
  <date>: <what replaced it and why>` directly beneath the original entry, original text intact.
- Each new entry: the trap, why it happens, and the correct pattern with a code example, per the
  file's existing format.
- **Duplicate headings** resolved by the arbiter in Phase 2: apply the arbiter's merged text
  exactly (delete the duplicate, keep the merged section).
- **Undated entries** the arbiter chose to backfill: append `(date from git history commit <sha>)`
  provenance as instructed in the DECISION LOG. Do not backfill any entry the arbiter marked SKIP.

The builder's plan message must show the proposed full new GOTCHAS.md (it is opinion-laden — the
lead approves the whole file). Merge B4 last, after B1–B3. (No `plan_approval: true` — B4's plan is
its full-file proposal message; approve or request changes via `team_message` and, if it stalls like
the Phase-3 builders can, force-shutdown + re-spawn without the flag.)

---

# PHASE 4 — REVIEW & VERIFY

## Verifier spec

Spawn the verifier (`qa`, `worktree: false`, `claim_task: verify`, **instructed read-only — report
findings, do not edit**). Give it: the DECISION LOG, the merged diff scope, the shared rules, and
the check list below. It must verify **every APPLY row was implemented as specified** and report:

- **GOTCHAS.md** follows its own stated `## Adding New Entries` convention (top-insert, format,
  RESOLVED/Superseded markers, no lost original text).
- **No wikilinks** (`[[...]]`) introduced anywhere:
  `rg -n '\[\[.*\]\]' --glob '*.md' --glob '!**/node_modules/**' --glob '!**/.git/**' .`
- **No broken relative links** introduced: re-resolve the link list from LIVE CONTEXT plus any new
  links, `test -f "$(dirname "$SOURCE_FILE")/$TARGET"` per link.
- **No `## Related Modules` sidecar** was hand-edited or rendered from an unfiltered query.
- **Only owned files changed** per builder; no overlap, no unexpected file types.
- **No nix file was modified** (this command only edits docs). If any `.nix` changed, flag it and
  run `nix fmt -- --check` + `nix flake check --no-build` on the result before merging.

The verifier reports `VERIFY PASS` or a list of `VERIFY FAIL` items with file:line. Any FAIL goes
back to the owning builder (message it, re-merge, re-verify) or is fixed directly by you for
trivial issues, recorded in the report.

> **Verifier baseline (dirty tree).** If the working tree was dirty at start, the verifier must
> compare against the **pre-edit dirty state + DECISION LOG rows** (i.e. what the builders should
> have produced), NOT against committed HEAD — `git diff` against HEAD will include the prior
> pass's changes and make every file look "modified outside scope." The lead should capture the
> pre-edit dirty diff (`git diff` output or a stashed copy) before Phase 3 so the verifier has a
> baseline. Confirmed 2026-08-03: without this, a verifier flags all 14 pre-existing dirty files
> as builder errors.

## Lead's final verification (run yourself before `team_cleanup`)

```bash
git diff --stat                    # confirm only intended .md files changed
rg -n '\[\[.*\]\]' --glob '*.md' --glob '!**/node_modules/**' --glob '!**/.git/**' .   # no wikilinks
git diff --name-only | grep -c '\.nix$'   # must be 0
```

If any `.nix` file changed: `nix fmt -- --check` and `nix flake check --no-build` must pass before
cleanup.

---

# PHASE 5 — REPORT

Compile the single coherent report for the human — one document, not stitched transcripts.

## 1. Decision log summary

A condensed version of the DECISION LOG showing what was decided and why:

```
DECISIONS:
- STRUCTURE.md: 3 stale claims fixed, 2 sections added
- GOTCHAS.md: duplicate "## Format" merged (<rationale>), 2 entries backfilled from git
  history (<shas>), 1 RESOLVED marker added
- 2 broken links repointed (old → new), 1 removed (no target found: <concept>)
- Skipped: <n> findings (with reasons)
- Overrides: <n> (list both positions)
```

## 2. Final table

| File | Action | Lines before | Lines after | Status |
|------|--------|-------------|-------------|--------|
| STRUCTURE.md | Updated | 45 | 67 | ✓ |
| modules/nixos/gotty/README.md | Created | 0 | 34 | ✓ |
| GOTCHAS.md | Updated | 82 | 95 | ✓ |
| Link integrity | N checked | — | — | M fixed |
| Related Modules sidecars | N checked | — | — | M refreshed |

## 3. Out-of-scope & NOTE items

List any documentation gaps that were out of scope for this pass (e.g. modules with complex
enough behaviour that proper docs would require hardware testing to verify), plus every NOTE-status
finding and every OVERRIDE the team made.

**Note:** the team writes files but does not commit them. The merged result is left as unstaged
changes for the human to review. If commits are wanted, run them manually per your usual
one-concern-per-commit discipline after reviewing, or say the word and this command can be
extended with a per-file commit step matching `nix-refine`'s pattern.

---

# PHASE 6 — SELF-IMPROVEMENT (optional, `SELF_IMPROVE=true`)

> Skip this entire phase when `SELF_IMPROVE=false`. Everything below only runs when the toggle is
> on. Its scope is **this command file only** — it never touches repo docs (those are Phases 1-5).

## Why

Every run of this command exercises its own instructions. When an instruction is wrong, stale, or
wasteful (a broken flag, a worktree trap, a merge that silently applies nothing), the next run
repeats the cost. Phase 6 captures those lessons *in the command itself* so each run can optionally
improve the tool that drives it.

## 6.1 Capture run-time lessons (lead, as you go)

During the run, keep a short scratch list of operational facts about **this command's own
execution** — not repo-doc findings. Examples of real lessons (2026-08-03):
- `plan_approval: true` never wakes builders after approval → must re-spawn without the flag.
- Builder worktrees fork at committed HEAD; the dirty working tree is the audit target → builders
  must `cp` the main-repo file over their worktree copy before editing.
- `team_merge` silently applies nothing when a builder only stashed (uncommitted) its work →
  the lead must copy the worktree files into the main repo directly and verify.
- Scouts that read their worktree (committed HEAD) instead of the main repo path produce false
  STALE/MISSING findings → scouts must be told to read `/home/seanc/nixos-config/<path>`.

Each lesson must be grounded in something that actually happened this run (file:line or a concrete
observed behavior). Do not invent lessons.

## 6.2 Audit this command file (meta-scout)

Spawn **one** read-only scout (`general`, `worktree: false`, `claim_task: self-improve`) whose
only job is to audit `modules/home/opencode/commands/nix-doc-audit.md` against:
- The live run just completed (the run-time lessons from 6.1).
- The actual repo state (do the commands it references exist? are the paths it names current?).
- Internal consistency (duplicate headings, stale line refs, box-drawing breakage, unbalanced
  code fences, references to files that don't exist).

Give the scout: the run-time lessons, the shared rules at the top of this command, and this
instruction. It reports findings in the same STALE / MISSING format with `file:line` evidence,
ending with `AUDIT COMPLETE`.

## 6.3 Decide & apply (lead, directly — no builders)

The lead triages the meta-scout's findings with the same APPLY / SKIP / NOTE protocol:
- **APPLY** only when the change is grounded in this run's reality (a real failure) or the actual
  current repo (a stale path/command). If it would require guessing, SKIP and NOTE instead.
- Apply edits **directly to this command file** — this is the lead's own tool, no worktree needed.
- Do not add aspirational self-healing ("in future we might..."); only fix what is true now.
- Do not let Phase 6 balloon the file; keep each fix tight and referenced to the lesson.

## 6.4 RUN LOG → `learning_append` (proposal-only, gated)

**The lead no longer appends RUN LOG entries to this command file directly.** Any self-improvement
action anywhere in nixos-config — editing a command, editing a skill, creating a new skill — must be
proposed via `learning_append` and gated via `learning_promote` before being applied. Direct
unlogged edits to command/skill/tool files during a self-improvement pass are not permitted. For
each operational lesson captured in 6.1, call the goals MCP tool **`learning_append`** with:

- `command` = `"nix-doc-audit"` (this command's own name)
- `lesson` — one line: what happened and why the command misled/wasted effort
- `fix` — what the command file should change to apply the lesson
- `evidence` — `file:line` of the observed failure or verbatim command output (REQUIRED;
  the tool rejects empty/placeholder evidence, so never pass "placeholder" or prose)
- `target_type` / `target_path` — use `new_skill`/`new_command` only when proposing to create a
  file; otherwise leave the default `edit_existing`

`learning_append` writes the row with `status = 'proposed'` and dedupes against an existing open
learning with the same command + near-duplicate lesson. The actual command-file edit the learning
describes is **not** applied in this run: it happens in a separate reviewed step (a human, or the
automated `learning-promoter` agent) after
`learning_promote(<id>, "validated", acted_on_commit=<commit>)` has been called with the hash of
the edit. Do not call `learning_promote` yourself, and do not apply the learning's edit silently.
A review/promotion session reads the queue with `learning_query`.

**Historical record:** the RUN LOG entries below (from before this mandate) remain in this file
as history and are **not** migrated to the learnings tables — migrating history is a separate
decision, and ungated history must not be falsely marked as validated.

## RUN LOG

### 2026-08-03 — `plan_approval: true` never wakes builders after approval
- Lesson: Spawning B1-B3 with `plan_approval: true` made each builder send its plan, end its
  run-cycle, and go idle forever — the lead's `team_message` `approve: true` response was stored
  but never delivered ("teammate has completed their task — message will not wake them"). All three
  builders stalled with zero edits until force-shutdown and re-spawn.
- Fix: Removed `plan_approval: true` from the spawn instructions everywhere. The DECISION LOG IS the
  approval — embed APPLY rows directly in the builder prompt. Added a WARNING block in "Spawn
  sequence & merge order" documenting the trap and the force-shutdown + re-spawn recovery.

### 2026-08-03 — builder worktrees fork at committed HEAD, not the dirty working tree
- Lesson: The main repo had 14 uncommitted `.md` changes (the actual audit target). Builders' git
  worktrees were created at committed HEAD, so their local copies were stale (e.g. README.md 140
  lines vs 156 dirty). Editing the stale copy would have made the merge clobber real work.
- Fix: Added a mandatory pre-edit sync step to every builder: `git rev-parse --show-toplevel`,
  `cp /home/seanc/nixos-config/<file> <worktree>/<file>`, `diff` to confirm identical, then edit.
  Added the same guidance to the LIVE CONTEXT working-tree check.

### 2026-08-03 — `team_merge` silently applies nothing for uncommitted builder work
- Lesson: Builders that only stashed their changes (uncommitted) produced an empty `team_merge`
  result — the merge reported success but applied nothing, so the main repo kept the old content.
  The lead had to copy files from the worktree manually.
- Fix: Documented in "Spawn sequence & merge order" that when `team_merge` applies nothing, the
  lead must `cp <worktree>/<file> /home/seanc/nixos-config/<file>` after verifying the worktree
  diff shows exactly the intended edits.

### 2026-08-03 — scouts reading their worktree produce false findings against a dirty tree
- Lesson: s-gotchas audited the committed-HEAD GOTCHAS.md (via its worktree) and reported the
  launchd/hyprland mkForce sites as MISSING — but the dirty working-tree GOTCHAS.md already
  documents both. This forced a full arbiter-pass correction.
- Fix: Spawn-sequence step 1 now tells every scout explicitly to read files from the main repo
  checkout (e.g. `/home/seanc/nixos-config/<path>`), not a worktree copy; the lead reconciles
  scout findings against the dirty files before composing the arbiter prompt.

### 2026-08-03 — `## Related Modules` sidecars: scope decision
- Lesson: No module README had a sidecar block (the A8 machinery existed but nothing had been
  generated). The arbiter chose the middle path: add sidecars to the 36 common.nix-imported,
  graph-tracked modules + home/core + home/opencode, and NOTE the rest (graph-less modules render
  "not tracked", per A8 rule 5).
- Fix: Recorded the decision in the DECISION LOG as row 12; this pass applied it. Future runs
  should re-run A8 against the now-existing sidecars (they can now go stale like prose).

### 2026-08-03 — ownership carve-out needed for opencode README/AGENT.md
- Lesson: `modules/home/opencode/README.md` + `AGENT.md` matched both `b-modules`'s generic
  `modules/home/*/README.md` glob and `b-skills`'s skill-ecosystem scope. Without an explicit
  carve-out, two builders would have edited the same file in parallel.
- Fix: Added an "Ownership carve-outs" note in Phase 3 telling the lead to resolve such overlaps
  in both builder prompts before spawning.

### 2026-08-03 — `team_merge` REFUSES dirty files; git-restore is the real merge path
- Lesson: `team_merge` returned `Cannot merge <builder> — you have local changes to the same files`
  on ALL FOUR builder merges this run, because every target `.md` was dirty in the main checkout
  (the audit target itself). The command only documented the "applies nothing" (stash) case, so the
  refusal case was unanticipated; the preserved branch
  (`ensemble/preserved/<team>#<run>/<builder>`) holds each file as "dirty baseline + intended
  edits", which is exactly what the main tree needs.
- Fix: Documented the dirty-tree refusal as the PRIMARY merge path for dirty trees with the
  `git diff`-verify → `git restore --source=<preserved-branch> --worktree -- <files>` → `git diff`
  verify recovery in Spawn-sequence step 4, plus spot-check of DECISION LOG strings.

### 2026-08-03 — completed arbiter can't be woken; lead override is the effective disagreement path
- Lesson: The arbiter's M11 ruling (ventoy README) was SKIP based on a faulty grep that claimed 0
  matches; the pattern actually matched 5 times (README lines 4,10,11,28,29,131 all reference
  non-existent `modules/flake-parts/ventoy.nix`/`ventoy-config.nix`). The lead messaged the arbiter
  to reconsider, but a completed arbiter's run-cycle is over — the message was stored, never
  delivered ("teammate has completed their task — message will not wake them"). The lead verified
  the finding directly and overrode M11 to APPLY.
- Fix: Added a note to the Disagreement protocol that a completed arbiter can't be woken, so the
  effective path is lead verification + OVERRIDE recorded in the DECISION LOG (and included in the
  owning builder's prompt).

### 2026-08-03 — `team_tasks_add` `depends_on` label trap
- Lesson: Passing the task-board labels (`triage`, `build-*`) as `depends_on` values instead of the
  returned IDs (`task_<rand>_<n>`) left all four build tasks permanently `[blocked] by unresolved
  dependencies`; b-modules could not claim its task. Builders had to proceed without claiming; the
  lead used `team_tasks_complete` on the build tasks to unblock the verifier.
- Fix: Added an explicit "`depends_on` label trap" note to the Task board section: labels are
  illustrative, use returned IDs, and if tasks get phantom-blocked, proceed without claiming and
  `team_tasks_complete` them once the builder is done.

### 2026-08-03 — OVERRIDE rows must be cross-checked into builder prompts
- Lesson: The M11 override row (flipped SKIP→APPLY after lead verification) was never passed to
  b-modules — its prompt listed M1–M10 only — so the ventoy README fix was missed until the lead
  caught it post-verifier and applied it directly.
- Fix: Added "before spawning each builder, cross-check every OVERRIDE row for that builder's group
  is present in its prompt" to Spawn-sequence step 4.

# END OF COMMAND
