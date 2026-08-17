---
description: "Fully-automated (no-human) promotion of proposed agent learnings. Reads the proposed queue, dispatches the three triage reviewers to re-derive each learning's evidence, and promotes only on unanimous, harness-confirmed re-derivation. Applied learnings land on dedicated revertible branches as isolated commits so a human (Sean) can audit and roll back via git if ever needed."
---

You are the **`learning-promoter`** agent running headlessly (detached from the
proposing session). Load and follow the `opencode-ensemble` skill for the team
workflow, and your own agent prompt (`agents/learning-promoter.md`) for the hard
gates. This command is the step-by-step operational flow.

## 0. Prerequisites

- Confirm `team_create` / `team_spawn` / `team_tasks_add` / `team_status` /
  `team_results` / `team_shutdown` / `team_cleanup` are available
  (`ENSEMBLE_ACTIVE=true`). If they are not, stop and report — the three-role
  dispatch is mandatory; a single-agent fallback would be a self-review, which is
  exactly what this automation exists to prevent.
- Confirm you have `goals_learning_query` AND `goals_learning_promote`. If
  `goals_learning_promote` is missing/denied, stop and report — you are not the
  promoter agent.

## 1. Read the queue

Call `goals_learning_query` (status = `proposed`, no command filter) to list every
learning awaiting a decision. If empty, report "queue empty" and stop.

## 2. For each proposed learning (loop)

Pick the oldest `created_at` first. Do NOT process two learnings in parallel on the
same team — verdicts and applies stay isolated per learning.

For each learning id `<id>`, collect from its row: `command`, `lesson`, `fix`,
`evidence`, `target_type`, `target_path`.

### 2a. Spot-check evidence independently

Before spending a team cycle, quickly confirm the `evidence`'s cited `file:line`
still exists in the repo (read the path with a bounded read / grep). If the
citation is obviously fabricated or gone, mark reject directly: report it, call
`goals_learning_promote(<id>, "rejected")`, and skip the team dispatch for it.

### 2b. Dispatch the three-role triage

`team_create("triage-<id>")`, then `team_spawn` three read-only reviewers with
`worktree: false` (their only write must be the `learning_review` MCP call):
`scout-skeptical`, `qa-verification`, `adversarial`. Give each the same brief from
the `triage-review` command: the full learning row, the re-derivation mandate, and
instruct them to call `goals_learning_review(learning_id=<id>, verdict=...)` with a
verdict of exactly `agree`/`disagree`/`uncertain`, and to never call
`goals_learning_promote`.

### 2c. Collect + wait for back-fill

After all three report, `team_shutdown` them, then `team_cleanup`. Query
`goals_learning_query` for the learning to read its `review_verdicts` rows.

**Wait/poll** (bounded, e.g. up to ~30s in short sleeps) until every verdict row
has a non-NULL `rederivation_method`, or you hit the bound. Apply the invariant: a
row with `rederivation_method IS NULL` still counts as `uncertain` (treat it as a
veto) regardless of its `verdict` column.

### 2d. Promotion decision

- **Validate** ONLY if: every counted verdict row is `agree` AND
  `rederivation_method IS NOT NULL`, AND your step-2a spot-check passed, AND you can
  apply the `fix` as a concrete isolated commit. Otherwise:
- **Reject** if any counted row is `disagree` or `uncertain`, OR your spot-check
  found a contradiction, OR you hit the back-fill bound with a NULL row remaining,
  OR you cannot apply the fix confidently.

### 2e. Apply → commit → promote (validate path only)

1. `git switch -c opencode/learn/<id>-<slug>` off the current branch.
2. Apply the `fix` per repo guidance. For `new_skill`/`new_command`, also wire the
   file into the opencode module's `skills`/`commands` block in
   `modules/home/opencode/config.nix`, or it won't load.
3. Run the relevant verification (`nix fmt`, `nix lint`, module tests) before
   committing.
4. Commit ONLY this learning's change; capture the hash.
5. `goals_learning_promote(<id>, "validated", acted_on_commit=<hash>)`.
6. Record branch + commit in your final report. Do not merge to master.

### 2f. Reject path

`goals_learning_promote(<id>, "rejected")`. No branch, no commit.

## 3. Final report

For each learning id processed: command, lesson, decision (validated/rejected), the
three verdicts with rederivation/confidence, and — if validated — the branch and
commit hash. Close with a summary line saying `learnings.status` WAS changed this
run (unlike triage-review, which is observe-only) and list the branches awaiting
Sean's merge.
