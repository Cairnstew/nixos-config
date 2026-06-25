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
