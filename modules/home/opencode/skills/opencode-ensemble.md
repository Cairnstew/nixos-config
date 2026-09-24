---
name: opencode-ensemble
description: "Use when coordinating multiple coding agents, delegating independent software work, managing OpenCode Ensemble teams, choosing teammate roles or models, reviewing teammate output, or deciding whether parallel execution is appropriate."
---

# OpenCode Ensemble

Use OpenCode Ensemble as a coordination system, not a shortcut for avoiding judgment. Parallel agents work best when the lead owns decomposition, sequencing, review, merge, and verification.

## Core Principle

Spawn teammates only for independent, verifiable work. A good Ensemble team has narrow task ownership, clear dependencies, and a lead that integrates results deliberately.

## Use Ensemble When

- Work can be split into independent research, implementation, test, or review slices.
- A read-only scout can map unfamiliar code before edits begin.
- Multiple files or subsystems can be changed without overlapping ownership.
- A risky change benefits from `plan_approval: true` before edits.
- A final reviewer can inspect merged changes without creating another branch.

## Do Not Use Ensemble When

- The task is small enough for one agent to finish quickly.
- The work is tightly coupled and every teammate would need the same files.
- The lead cannot describe each teammate's output and success criteria.
- The user needs one coherent design decision rather than parallel exploration.
- You are tempted to spawn agents because the task feels hard but not divisible.

## Lead Workflow

1. Decide whether parallelism is justified.
2. Create a team with `team_create`.
3. Add tasks with `team_tasks_add`; use `depends_on` for sequencing.
4. Spawn teammates one at a time with `team_spawn`.
5. Use `worktree: false` for read-only `explore` teammates.
6. Use `plan_approval: true` for risky implementation work.
7. Wait for teammate messages instead of polling status repeatedly.
8. Read full results with `team_results` when messages are truncated or consequential.
9. Shut down completed teammates with `team_shutdown`.
10. Merge branches with `team_merge`; inspect the diff before trusting it.
11. Run project verification before `team_cleanup` and before claiming done.

## Role Defaults

| Role | Agent | Worktree | Use for |
|---|---|---|---|
| Scout | `scout` | `false` | Codebase mapping, risk discovery, file ownership plan |
| Builder | `build` | `true` | Narrow implementation slice |
| QA | `qa` | `true` | Tests, fixtures, regression coverage |
| Reviewer | `reviewer` | `false` | Diff review, risk review, missed-test review |

Start with two or three teammates. Add more only when the work has more independent slices than active teammates.

## Hard Rules

- Do not invent task IDs. `team_tasks_add` generates IDs; use the IDs returned by earlier calls when setting `depends_on` or `claim_task`.
- Keep teammate prompts short. The plugin already injects team role, allowed tools, worktree context, and the required task-result format.
- Do not give teammates vague prompts like "fix the bug" or "work on tests".
- Do not ask teammates to use lead-only tools such as `team_spawn`, `team_shutdown`, `team_merge`, `team_cleanup`, or `team_view`.
- Do not tell teammates to report only in plain text. They must use `team_message`.
- Do not merge a teammate branch without reading its result and inspecting the diff.
- Do not call the work complete until the repository's verification commands pass or you have clearly reported the blocker.

## NixOS-Specific Guidance

This repository is a multi-system Nix flake. Refer to the `nixos-ensemble-decomposition` skill for how to split NixOS configuration work into independent, parallel slices.

## Agent Spaces

Agent Spaces let you spawn teammates into **separate, independent repositories** instead of git worktrees. Each space is a full clone of a repo, giving the teammate complete isolation — its own git history, its own working directory, no shared state with the lead.

### When to Use Spaces

- The teammate needs to work in a **different repo** than the lead (e.g. a plugin source repo, a separate project).
- The teammate's work should **not** be on a branch of the current repo.
- You want to test changes against an **external codebase** before integrating.
- The teammate needs its own git remote for push/pull (independent from the lead's).

### When NOT to Use Spaces

- The teammate is modifying files in the **same repo** as the lead — use a worktree instead.
- The work is a small, focused change that belongs on a branch of the current project.
- You need to review and merge the teammate's work back into the current repo.

### Configuration

Spaces are defined in `ensemble.json` under the `spaces` key:

```json
{
  "spaces": {
    "ensemble": {
      "path": "/home/seanc/Projects/opencode-ensemble",
      "agent": "build",
      "description": "Ensemble plugin source repo"
    }
  }
}
```

Each space entry supports:
- **`path`** (or `url`): Local path or git URL to clone from. Exactly one required.
- **`agent`**: Default agent type for teammates spawned into this space (e.g. `build`, `explore`).
- **`description`**: Human-readable description shown in tool hints.
- **`flakeInput`**: Optional flake input name — on clean+pushed shutdown, the lead gets a notification with the SHA and `nix flake lock --update-input` command.
- **`autoUpdateFlakeInput`**: If `true`, automatically runs `nix flake lock --update-input` after a clean shutdown.

### Usage

```
team_spawn(name="worker", space="ensemble", prompt="fix the bug in src/foo.ts", worktree=false)
```

- The teammate works in the cloned space directory, not a worktree.
- `worktree=false` is required (spaces and worktrees are mutually exclusive).
- On first spawn, the plugin clones the repo into `~/.config/opencode/ensemble-spaces/<space-name>/`.
- On subsequent spawns, it fetches and fast-forwards (refuses if dirty or diverged).

### Shutdown Behavior

- **Clean + pushed**: Teammate shuts down cleanly. If `flakeInput` is set, lead gets a notification with the commit SHA and update command.
- **Dirty worktree**: Teammate is force-aborted, lead is notified with push instructions.
- **Unpushed commits**: Teammate is force-aborted, lead is notified with the unpushed count.

### Available Spaces

| Space | Repo | Description |
|-------|------|-------------|
| `ensemble` | `Cairnstew/opencode-ensemble` | Ensemble plugin source — fix wake-path bugs, add features |
| `agenix-manager` | `Cairnstew/agenix-manager` | Agenix-manager — fix bugs, add secret lifecycle features |

### Using Spaces for Upstream Fixes

When a bug or feature request involves an external dependency managed in this repo, use a space to work directly in that dependency's source:

1. **Identify the space**: Check the Available Spaces table above, or add a new space in `modules/nixos/homeManager/config.nix`.
2. **Spawn into the space**: `team_spawn(name="fix", space="agenix-manager", prompt="fix the bug in ...", worktree=false)`
3. **Teammate works in the cloned repo**: Makes changes, commits, pushes to the upstream remote.
4. **Teammate shuts down**: Lead gets notified with the commit SHA.
5. **Update the nixos-config pin**: After the upstream fix is pushed, update the flake input or vendored copy in this repo.

This pattern is ideal for:
- Fixing bugs in vendored plugins (opencode-ensemble, agenix-manager)
- Adding features to upstream tools before they land in nixpkgs
- Testing changes against an external codebase without polluting the current repo
