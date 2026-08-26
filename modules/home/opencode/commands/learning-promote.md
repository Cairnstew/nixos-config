---
description: "Fully-automated (no-human) promotion of proposed agent learnings. Reads the proposed queue, dispatches the three triage reviewers to re-derive each learning's evidence, and promotes only on unanimous, harness-confirmed re-derivation. Applied learnings are auto-merged into the base branch as isolated commits whose git history is the audit/rollback net."
agent: learning-promoter
---

You are the **`learning-promoter`** agent. Load and follow the
`opencode-ensemble` skill for the team workflow, and your own agent prompt
(`agents/learning-promoter.md`) for the hard gates. This command is the
step-by-step operational flow.

## Launching the promoter

### Auto-launch (systemd watcher — recommended)

When `my.programs.opencode.learningPromoterWatcher.enable = true` (set in
your host config), the system is fully automated:

1. A **persistent `opencode serve`** headless server runs as a systemd user
   service (`opencode-serve.service`). It hosts the opencode runtime without
   a TUI — no tmux, no browser, just an API.

2. A systemd user timer polls the goals DB every ~1 minute:

   a. **Reconcile partial verdicts** — if a previous promotion session crashed
      mid-triage, some learnings may have 1-2 verdicts but not all 3. The watcher
      force-rejects these so they can be re-triaged fresh.
   b. **Reconcile stale learnings** — proposed learnings with zero verdicts
      older than the staleness threshold (default 10min) are force-rejected.
      These were never triaged (server was down, promoter crashed before
      triage, etc.).
   c. If `learnings` has any `status = 'proposed'` rows and no promotion is
      already running, the watcher sends `/learning-promote` via
      `opencode run --attach http://127.0.0.1:<port> --auto --format json`.
   d. The `--auto` flag bypasses permission dialogs. The `--format json`
      flag gives structured output for logging.
   e. **Promotion timeout** — if the promoter takes longer than
      `promotionTimeout` (default 30min), the watcher cleans up and retries
      on the next cycle.

3. Once the queue is empty, the watcher exits and waits for the next timer tick.

The watcher's service and timer are managed by systemd user services:
```bash
systemctl --user status opencode-serve.service      # headless server
systemctl --user status learning-promoter-watcher.timer   # watcher timer
systemctl --user status learning-promoter-watcher.service # latest run
```

Configuration options:
- `learningPromoterWatcher.repoDir` — repo path (default: `~/nixos-config`)
- `learningPromoterWatcher.goalsDb` — goals DB path (default: `~/.local/share/goals/goals.db`)
- `learningPromoterWatcher.checkInterval` — timer interval (default: `1min`)
- `learningPromoterWatcher.servePort` — opencode serve port (default: `4096`)
- `learningPromoterWatcher.promotionTimeout` — max seconds per cycle (default: `1800`)
- `learningPromoterWatcher.stalenessThreshold` — seconds before never-triaged learnings are rejected (default: `1800`)
- `learningPromoterWatcher.commandTimeout` — max seconds for `opencode run --attach` (default: `600`)

### Manual launch

If the watcher is not enabled, launch manually:

> **ALWAYS pass `-m <model>` explicitly when dispatching `/learning-promote`
> manually.** The watcher resolves the pipeline's dedicated chain and injects
> `-m` itself; a bare manual dispatch gets the wrapper's DEFAULT-chain model
> instead (currently `opencode-go/ox-alpha-free` — a free-tier terminal), which
> violates the D3 rule that promotion decisions never run on the free tier.
> Resolve the intended lead first with
> `opencode-model-select --agent learning-promoter` (exit 5 = chain BLOCKED —
> do not dispatch) and pass that model:
> `opencode run --attach http://127.0.0.1:4096 --auto -m "$(opencode-model-select --agent learning-promoter)" /learning-promote`

**Option A: Via the headless server (recommended)**
```bash
# Start the headless server
opencode serve --port 4096 &

# Send the command
opencode run --attach http://127.0.0.1:4096 --auto /learning-promote
```

**Option B: Via the interactive TUI (for debugging)**
1. Start a tmux window: `tmux new-session -d -s promoter "opencode /path/to/nixos-config"`
2. In the TUI, press `Tab` to cycle agents until **Learning-Promoter** is selected.
3. Type `/learning-promote` and press **Enter twice** — the first Enter opens the
   command palette, the second dispatches the command.
4. Expect permission-request dialogs (e.g. `/mnt/data/minecraft/logs`) — approve
   them with a keypress (or use `--auto` flag).
5. Leave the tmux session running; the lead must stay alive while the reviewers
   report back asynchronously. Poll with `tmux capture-pane -t promoter -p`.

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
same team — verdicts and applies stay isolated per learning. After each learning
completes (validated or rejected), re-query the queue with `goals_learning_query`
before moving to the next — new learnings may have arrived during triage.

For each learning id `<id>`, collect from its row: `command`, `lesson`, `fix`,
`evidence`, `target_type`, `target_path`.

**Merge conflict guard**: before creating the learning branch, check that the
base branch hasn't moved since you started:
```bash
git fetch origin server
git log --oneline HEAD..origin/server
```
If there are new commits (e.g. from a previous learning in this batch that was
just merged), rebase your starting point. If the learning's `fix` touches files
already modified by a prior learning in this batch, reject with a conflict note.

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

### 2e. Apply → commit → promote → merge (validate path only)

1. `git switch -c opencode/learn/<id>-<slug>` off the current branch.
2. Apply the `fix` per repo guidance. For `new_skill`/`new_command`, also wire the
   file into the opencode module's `skills`/`commands` block in
   `modules/home/opencode/config.nix`, or it won't load.
3. Run the relevant verification (`nix fmt`, `nix lint`, module tests) before
   committing.
4. Commit ONLY this learning's change; capture the hash. Re-verify
   `git branch --show-current` is your learning branch and the hash is on it
   before promoting — the session can silently check back to the base branch.
5. `goals_learning_promote(<id>, "validated", acted_on_commit=<hash>)`.
6. **Auto-merge** the branch back into the base (working branch `server`, tracking
   `origin/server`) with a normal `git merge` (no force-push, no rewrite). Do not
   wait for a human to merge — the loop is fully automated; git log/revert is the
   rollback net.
7. Record branch + commit in your final report.

### 2f. Reject path

`goals_learning_promote(<id>, "rejected")`. No branch, no commit.

## 3. Final report

For each learning id processed: command, lesson, decision (validated/rejected), the
three verdicts with rederivation/confidence, and — if validated — the commit hash
and the merge performed. Close with a summary line saying `learnings.status` WAS
changed this run (unlike triage-review, which is observe-only) and confirm every
validated learning's commit was merged into the base branch.
