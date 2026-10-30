---
description: Unattended, git-tracked data-quality audit + improvement of any repository's data pipeline. Orchestrates an opencode ensemble team and improves itself after each run (SELF_IMPROVE).
agent: build
subtask: false
---

You are the LEAD of a fully unattended data-quality run on **this repository's** data pipeline.
There is NO human available. Never ask questions, never wait for approval, never stop to
"confirm". When something is ambiguous, pick the most conservative option, write the decision to
`reports/data-quality/<RUN>/DECISIONS.md`, and continue.

This command is **repository-agnostic**. It must work in a Python data project, a Node/TS
scraper, a Rust ETL binary, a Go collector, a NixOS config with generated data, or a plain
shell+`jq` pipeline. Everything below that names a concrete tool is a *default*, not an
assumption — detect first (Phase 1), then act.

Optional scope from the invoker (may be empty = whole pipeline): $ARGUMENTS

## Environment knobs (all optional)

| Var | Default | Meaning |
|-----|---------|---------|
| `DQ_DIR` | `reports/data-quality` | Artefact root; `ROOT="$DQ_DIR/$RUN"` |
| `DQ_MAX_ATTEMPTS` | `12` | Improvement attempts before stopping |
| `DQ_WALL_HOURS` | `3` | Wall-clock cap |
| `DQ_PUSH` | unset | If set **and** `gh` is authenticated **and** the remote is GitHub → push + PR |
| `DQ_LESSONS_FILE` | unset | Explicit append target for Phase 6 (must be git-tracked) |

## Context (injected at start)

- Repo root: !`git rev-parse --show-toplevel 2>/dev/null || echo "(not a git repository)"`
- Current branch: !`git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?"`
- Base commit: !`git rev-parse --short HEAD 2>/dev/null || echo "?"`
- Run id: !`date -u +%Y%m%d-%H%M%S`
- Working tree state: !`git status --porcelain 2>/dev/null | head -20`
- Default branch / remote: !`git symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "(no origin/HEAD)"; git remote -v 2>/dev/null | head -2`
- Project markers: !`for f in flake.nix justfile Makefile pyproject.toml uv.lock requirements.txt package.json pnpm-lock.yaml yarn.lock Cargo.toml go.mod Gemfile composer.json setup.py; do [ -e "$f" ] && echo "found: $f"; done; echo "tools:"; for t in uv pytest ruff pyright npm pnpm yarn cargo go just jq python3 sqlite3 duckdb nix; do command -v "$t" >/dev/null 2>&1 && printf '%s ' "$t"; done; echo`
- Data footprint (tracked files by extension): !`git ls-files 2>/dev/null | sed -n 's/.*\.\(jsonl\|ndjson\|csv\|tsv\|parquet\|feather\|arrow\|sqlite3\|sqlite\|db\|db3\|h5\|hdf5\|zst\|gz\)$/\1/p' | sort | uniq -c | sort -rn | head -15`
- Candidate raw/append-only paths: !`git ls-files 2>/dev/null | grep -Ei '(^|/)(data|raw|record(ings|ed)?|ledger|store|snapshots?|experiments)/' | head -25`
- Guidance files present: !`git ls-files 2>/dev/null | grep -E '(^|/)(AGENTS|AGENT|GOTCHAS)\.md$' | head -15; ls docs/lessons 2>/dev/null | head -5`
- Prior data-quality lessons: !`for f in "${DQ_LESSONS_FILE:-}" "$DQ_DIR/LESSONS.md" reports/data-quality/LESSONS.md; do [ -n "$f" ] && [ -f "$f" ] && { echo "--- $f"; tail -40 "$f"; break; }; done 2>/dev/null || true`

Use the run id above as `RUN`. All run artefacts live in `ROOT="$DQ_DIR/$RUN/"`.

## Hard rules

1. NEVER commit to, merge into, rebase, or force-push the **base branch** (the branch checked out
   at start). NEVER `reset --hard` or `clean` anything you did not create in this run. No
   `--no-verify`. All work happens on a new branch, `dq/$RUN`.
2. NEVER modify or delete **raw / recorded / append-only** data — recorder logs (JSONL/NDJSON),
   market-data stores, ledgers, snapshots under `experiments/`, and anything the repo documents as
   append-only. Fix quality problems **in code** (ingest, transform, validation), never by editing
   recorded data. Derived/cached outputs may be regenerated. If you cannot tell whether a path is
   raw, treat it as raw and record the decision in `DECISIONS.md`.
3. NEVER introduce lookahead/leakage. Any change touching timestamps, joins, resampling, labels or
   train/eval splits must be justified in its commit body and covered by a test. Repos with no ML
   stages simply skip the leakage probes — say so, do not fake them.
4. No secrets in commits, reports, or logs. No network calls beyond what the pipeline already
   does; if a stage normally calls an API, audit it from recorded/cached output instead.
5. Deterministic only: fixed seeds, no wall-clock or random-ID dependence inside checks. The audit
   must produce byte-identical JSON across two consecutive runs.
6. If the working tree is dirty, do not touch it. Do all work in a separate worktree. If this is
   not a git repository, stop immediately and report — git-tracked history is a precondition.
7. Stop conditions: wall-clock cap `$DQ_WALL_HOURS`, `$DQ_MAX_ATTEMPTS` improvement attempts, or
   2 consecutive failed/rejected stages. On stop, finish cleanly (Phase 5 → 6 → 7) rather than
   aborting mid-change.
8. Never assume the repo's language, package manager, test runner, default branch, or CI host.
   Detect them (Phase 1) and record what you detected in `PIPELINE_MAP.md`.
9. **No pipeline, no run.** Phase 0a decides whether this command applies to the repo at all. If it
   does not, stop and report — never scaffold tooling, never commit, never invent work, and never
   degrade into "general data quality". An empty audit is worse than no audit.

---

## ENSEMBLE GATING

Detect whether the team tools are actually present in this session (the plugin may be configured
but not loaded):

- If the tools `team_create`, `team_spawn`, `team_tasks_add`, `team_status`, `team_results`,
  `team_merge`, `team_shutdown`, `team_cleanup` are available to you right now →
  **`ENSEMBLE_ACTIVE=true`**.
- Otherwise → **`ENSEMBLE_ACTIVE=false`**, regardless of config.

- **`ENSEMBLE_ACTIVE=true`** — run Phase 2 and Phase 4 as a real team. Auditor work is read-only
  fan-out (spawn with `worktree: false`); implementer work is isolated (spawn with
  `worktree: true`, one branch per item). Spawn in **waves of 2**, one verification at a time, so
  concurrent test/audit runs do not exhaust memory. Never poll `team_status`/`team_tasks_list` —
  wait for the teammate message, then read `team_results`.
- **`ENSEMBLE_ACTIVE=false`** — run a single-agent fallback: you play every role (auditor,
  planner, implementer, reviewer) in order, applying the **same** protocol and the same
  independent-review rule (you must review your own diff as a separate step, against the metric,
  after a clean checkout of the branch). State `ENSEMBLE_ACTIVE=false — serial fallback` in
  `PIPELINE_MAP.md` so the report is honest about how it ran.

---

## Phase 0: Preflight, then isolate (git)

### 0a. Is there a data pipeline at all? (read-only, in the main tree)

Decide this **before** creating any branch, worktree, tag, or commit. It is cheap — `git ls-files`
plus a handful of greps, no data loading. Classify the repo into exactly one class:

| Class | Test |
|---|---|
| **`PIPELINE`** | (a) code that reads a data source **and writes a different persistent artefact**, and (b) at least one artefact that a later stage or downstream consumer reads back |
| **`DATA_ONLY`** | data artefacts exist (committed or generated), but nothing transforms them into another artefact |
| **`CODE_ONLY`** | code fetches/processes data but persists nothing another step consumes (prints to stdout, formats, renders) |
| **`NONE`** | neither — docs / config / pure library repo |

Collect evidence (read-only):

```bash
git ls-files | sed -n 's/.*\.\(jsonl\|ndjson\|csv\|tsv\|parquet\|feather\|arrow\|sqlite3\|sqlite\|db\|h5\|hdf5\)$/\1/p' | sort | uniq -c | sort -rn
grep -rn -E '(write|dump|save|to_csv|to_parquet|to_json|INSERT INTO|\.write\()' --include='*.py' --include='*.ts' --include='*.js' --include='*.go' --include='*.rs' . | head -40
grep -rn -E '(read_csv|read_parquet|SELECT .+ FROM|json\.load|open\()' --include='*.py' --include='*.ts' --include='*.js' --include='*.go' --include='*.rs' . | head -40
# pipeline glue: targets/tasks that ingest, sync, import, export or rebuild data
grep -nE '^(ingest|sync|import|export|build|fetch|refresh|rebuild|generate)[a-z-]*:' justfile Makefile package.json 2>/dev/null
```

If the invoker passed a scope, apply the gate to the paths in that scope — but a scope that names
no pipeline is still a stop.

**If the class is `PIPELINE`** → continue to 0b.

**If the class is `DATA_ONLY`, `CODE_ONLY`, or `NONE` → STOP the run here:**

1. Do **not** create a worktree, branch, or tag. Do **not** commit anything. Do **not** scaffold
   `tools/dq_audit.*`, `PIPELINE_MAP.md`, or an empty `reports/` tree — a repo with no pipeline must
   not gain dead tooling. Leave the working tree exactly as found (it may be dirty).
2. Write the report to `$TMPDIR/dq-$RUN/NO-PIPELINE.md` (outside the repo) and print it in full:
   - the classification and the evidence that produced it (commands + counts, not adjectives)
   - the paths that looked like data (if any) and why they do not count
   - the missing half — a writer that persists an artefact, or a consumer that reads one back
   - up to 3 concrete, repo-specific next steps
3. Exit 0 with a short status. **A no-pipeline result is a correct outcome, not a failure.**

Explicitly out of scope when the gate fails:

- **Do not "improve data quality in general."** Data with no consumer has no contract, so no
  improvement can be given an acceptance rule — Phase 3 would drop every such item anyway. Do not
  invent metrics to justify work.
- **Do not audit or edit committed fixtures, samples, seed data, or `templates/`.** Those are test
  inputs, not production data: a `tests/fixtures/data/*.csv` is not a pipeline.
- **Do not build a pipeline just to have something to audit.** This command improves an existing
  pipeline; it does not invent one.

> Want the data artefacts themselves audited (nulls/dupes/schema in committed data) when there is no
> pipeline? That is a different job — say so in the report instead of silently degrading into it.

### 0b. Isolate (git)

Only when the class is `PIPELINE`:

```bash
git worktree add "../$(basename "$PWD")-dq-$RUN" -b "dq/$RUN"
```

Work only inside that worktree from now on. If `dq/$RUN` already exists (re-run in the same
second), suffix it. Create `$ROOT/` there and commit an empty `README.md` stub:
`chore(dq): start run $RUN`.

Everything after this point runs **inside the worktree**. Never `cd` back to the original tree to
make changes.

## Phase 1: Baseline

0. **Read prior lessons first.** If `$ROOT/../LESSONS.md`, `$DQ_LESSONS_FILE`, or the repo's own
   lesson home exists (see Phase 6.3), read it and apply its advice before anything else. Note in
   `PIPELINE_MAP.md` which lessons you applied and which no longer apply.
1. **Detect the toolchain.** Resolve, and record in `PIPELINE_MAP.md` under a `## Detection`
   table:
   - **Test runner** — first working of: `just test`, `npm test`, `pnpm test`, `cargo test`,
     `go test ./...`, `make test`, `uv run pytest`, `pytest`, `python3 -m pytest`. Verify it
     actually runs (a bare `--collect-only`/`--list` pass is enough) before trusting it.
   - **Lint/format** — `ruff`, `eslint`, `cargo clippy`, `golangci-lint`, `just fmt`, `nix fmt`,
     `prettier`. Skip silently if absent; never install one.
   - **Language runtime for the audit tool** — see 1.3.
   - **CI host** — `.github/workflows/` → GitHub; `.gitlab-ci.yml` → GitLab; none → no CI steps.
2. **Discover the pipeline.** Identify entrypoints, stages, data sources, schemas, existing
   tests/validators. Stage names are whatever this repo actually has; a typical shape is
   `sources → ingest/collect → normalise/transform → derive/aggregate → store/export → consume`.
   ML stages (`features → labels → train/eval`) exist only in ML repos — skip them and record why.
   Write `PIPELINE_MAP.md` with: detection table, stage graph, per-stage input/output paths,
   raw-vs-derived classification per path, and the resolved test/lint/audit commands.
3. **Run the existing test suite** and record pass/fail in `baseline-tests.txt`. Failing tests that
   pre-date this run are `known-red` and are not your job unless they are DQ-related. A suite that
   cannot run at all is a `blocked` stage, not a pass.
4. **Create the audit tool** if the repo has no equivalent. Otherwise extend the existing one —
   do not add a second convention.
   - Location: `tools/dq_audit.<ext>`, or inside the repo's existing tools/scripts directory if it
     has one.
   - Language: the repo's primary language; fall back to Python 3; a POSIX shell + `jq` script is
     acceptable for repos with no obvious runtime.
   - Contract: **read-only**, no temp writes outside `$TMPDIR`, deterministic (fixed seeds, no
     wall-clock), prints one JSON object per stage to stdout, **exits 0 even when anomalies are
     found** (anomalies are data, not errors), and never rewrites an input file.
   - Add tests for it in the repo's test framework.
   - Commit: `feat(dq): add deterministic data-quality audit`.
5. **Run it twice** and diff the output (`cmp`). If not byte-identical, fix determinism before
   proceeding. Save the first run as `baseline.json`. Commit:
   `chore(dq): record baseline metrics`.

Checks to cover (skip any that do not apply, record why in `PIPELINE_MAP.md`):
schema/dtype drift; nulls and NaN/inf; duplicate keys; timestamp monotonicity, timezone (UTC)
consistency, gaps vs expected cadence; outliers/spikes (robust z, bad ticks); stale or frozen
values; cross-source alignment; unit/scale consistency; label/feature leakage probes; train/eval
overlap; row-count conservation between stages; config-vs-code consistency.

## Phase 2: Audit (parallel team, read-only)

One AUDITOR per pipeline stage or data source, each with a narrow scope. Context budget matters:
each member must stay well under ~200k tokens, so give them **file paths and stage names, never
pasted data**, and make them sample/aggregate rather than load full datasets.

Each auditor writes `$ROOT/findings/<stage>.md` containing, per finding: id, severity
(critical/high/med/low), evidence (command + numeric result), root cause hypothesis, proposed
fix, risk, and the `dq_audit` metric that would prove the fix. Auditors do **NOT** edit code.
Lead commits all findings: `docs(dq): audit findings for <stage>`.

## Phase 3: Plan

Lead merges findings into `$ROOT/PLAN.md`: a ranked list of improvements
(severity × confidence / risk), each with its target metric, acceptance rule, and owning stage.
Drop anything that cannot be verified with a metric or test, and log it under "Not attempted" with
the reason. Commit: `docs(dq): improvement plan`.

## Phase 4: Improve (isolated branches)

Take plan items in rank order, up to `$DQ_MAX_ATTEMPTS`. For each item use one worktree and one
branch `dq/$RUN/<item-id>` created from `dq/$RUN`. Items that touch the same files run serially;
independent items may run in parallel (waves of 2, one verification at a time).

Implementer loop (max 3 tries per item):
1. Write/extend a failing test or metric check first.
2. Make the smallest change that fixes it.
3. Run the full test suite **and** the `dq_audit` tool.
4. Commit on the item branch: `fix(dq/<stage>): <what>` with a body containing evidence:
   metric before → after, tests added, risks.

Acceptance (an independent REVIEWER/EVALUATOR checks, never the implementer):
- target metric improved, no other metric regressed beyond noise
- full test suite no worse than baseline; new tests pass
- no leakage introduced (probes still clean); audit output deterministic across 2 runs
- diff touches only what the item needs

If accepted: lead merges with `git merge --no-ff dq/$RUN/<item-id>` into `dq/$RUN`, appends a row
to `$ROOT/LEDGER.md` (item, commit, metric before/after, verdict). With the ensemble, `team_merge`
squash-merges and leaves the result **unstaged** — commit it before spawning the next worktree
teammate. If rejected or conflicting: do not merge; record the reason in `LEDGER.md` and remove the
item branch's worktree only (keep the branch for traceability). Two consecutive rejections = stop
condition.

## Phase 5: Re-audit

On `dq/$RUN`, run the full test suite and the `dq_audit` tool; save `final.json`; write
`$ROOT/SUMMARY.md` with a before/after table per metric, accepted/rejected items, remaining
issues, and recommended follow-ups. Commit: `docs(dq): final metrics and summary`.

## SELF-IMPROVEMENT TOGGLE

This command audits its own guidance after every run. Phase 6 captures what THIS run learned about
**the command's own execution** in the repo it just ran against — not about the pipeline — and
leaves it where the next run will find it.

```
SELF_IMPROVE=true
```

- **`SELF_IMPROVE=true`** (current) runs Phase 6 after Phase 5, before the Phase 7 finish steps.
- **`SELF_IMPROVE=false`** skips Phase 6 entirely — Phases 0-5 and 7 still run unchanged.

Grounding discipline: every lesson must reference something that actually happened this run or
exists in the repo now (`file:line`, or the exact command and its output). Never invent
future-proofing. `no lessons this run` is a valid and expected result.

> **Portability note.** This command is global — it is not stored in the repo it audits, so it
> cannot edit itself from inside a run (the run is isolated on `dq/$RUN` and the base branch is
> off-limits). Phase 6 therefore *records* lessons in the audited repo and leaves the command edit
> to a human or to a later run in the repo that declares this file
> (`modules/home/opencode/commands/data-quality.md` in nixos-config). Do **not** try to write to
> the nixos-config checkout from a data-quality run.

## Phase 6 — Self-improvement (general to any repository)

### 6.1 Capture lessons as you go (lead, inline)

From Phase 1 onward, append to `$ROOT/LESSONS.md` whenever this command's own instructions
mislead you. A lesson is about the **command**, not the data:

- an instruction that was wrong or stale for this repo (a path, command, tool, or stage name it
  assumed)
- a step that silently no-op'd, or needed a manual workaround to do anything
- a detection the command should have done automatically and didn't
- a stop condition or acceptance rule that fired wrongly
- an environment trap (detached HEAD, no `origin/HEAD`, monorepo subdir, no test runner)

Format per entry:

```
- what the command said → what actually happened
  evidence: <file:line of the guidance> | <exact command + output>
  suggested edit: <one line>
```

If nothing qualified: write `no lessons this run` under a `## Lessons` heading and continue.
Do not manufacture lessons.

### 6.2 Audit only the guidance you actually relied on

Do not sweep the repo. Check the files this run obeyed or trusted:

- repo guidance you read — `AGENTS.md`, `AGENT.md`, `GOTCHAS.md`, `docs/**`, module `AGENT.md`
- the test/lint/CI config you trusted for the baseline
- any script or Makefile/justfile target you invoked

For each, report `OK` / `STALE` / `MISSING` with evidence: does the path exist, is the command
current, is the documented option still valid, does the RUN LOG's advice still hold. Put the table
in `$ROOT/LESSONS.md` under `## Guidance audit`.

This is where most real lessons come from — a stale path in `GOTCHAS.md` costs every future run.

### 6.3 Persist the lessons — append-only, in the audited repo

Choose exactly ONE destination, first match wins:

1. **`$DQ_LESSONS_FILE`** if set, exists, and is git-tracked.
2. **The repo's established lesson home** — only if the repo's own docs already define that
   convention, e.g. a `GOTCHAS.md` with a `## RUN LOG` section, a module `AGENT.md` with
   `### <date> —` entries, or a `docs/lessons/` directory.
3. **`$DQ_DIR/LESSONS.md`** — the default. This is a **cross-run** file (one level above `$ROOT`),
   so Phase 1 can read it next time. Do not put it inside `$ROOT`.

Rules:
- **Append-only.** Never delete, reorder, or rewrite earlier entries.
- Heading: `### <UTC date> — data-quality run <RUN>` then the bullets from 6.1.
- Never write into a raw/recorded/append-only data path, and never into a build output dir.
- If the destination lives on the `dq/$RUN` branch and Phase 7 does **not** push a PR, the lessons
  would be lost with the branch — so also echo them into the final status output.

Commit on `dq/$RUN` only: `docs(dq): run lessons`.

### 6.4 Efficiency lens (proposal only — never build it here)

Read `$ROOT/LEDGER.md` and the run timeline, and measure:

- attempts used vs `$DQ_MAX_ATTEMPTS`, and rejections
- how many times the audit tool was re-run by hand
- whether the same multi-step sequence repeated per stage or per item (e.g. re-deriving the test
  command, re-running the full suite to compare one metric)
- wall-clock span vs `$DQ_WALL_HOURS`, and which phase dominated

If one pattern genuinely repeated, append ONE entry under `## Tooling proposals` in the lessons
file: the idea, the measured repetition (counts, not vibes), and the words
**"proposal only — not built in this run"**. Never implement it in the same run. No repetition →
write `no efficiency proposal this run`.

### 6.5 Feed-forward (the only real loop)

The lessons file is the mechanism that makes later runs cheaper:

- Phase 1 step 0 must read it before writing `PIPELINE_MAP.md`.
- State explicitly which prior lessons were applied and which no longer apply.
- Never silently ignore a lesson — if it is wrong now, say so in `DECISIONS.md` and propose
  removing it (the human applies that).

---

## Phase 7: Finish

1. Ensure `dq/$RUN` is clean and every change is in a commit — including Phase 6's
   `docs(dq): run lessons`. Tag it `dq-$RUN` (if the tag already exists, use `dq-$RUN-<n>` and
   record which one you used).
2. If `$DQ_PUSH` is set **and** `gh auth status` succeeds **and** the remote is GitHub: push
   `dq/$RUN` and open a PR **into the base branch captured at start** (fall back to the detected
   default branch only when HEAD was detached), using `SUMMARY.md` as the body
   (`gh pr create --base <branch>`). A branch-per-host repo must get the PR against its host
   branch, not directly against the default branch — record the chosen target in `DECISIONS.md`.
   If any condition fails, do **not** push — say which condition failed.
3. Remove the temporary worktrees you created (not the branches).
4. Print a final 10-line status: repo, branch, tag, accepted/rejected counts, headline metric
   deltas, whether a PR was opened, the Phase 6 lesson count, and anything that needs a human
   decision next time.
