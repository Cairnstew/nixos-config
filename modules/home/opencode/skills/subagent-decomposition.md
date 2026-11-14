---
name: subagent-decomposition
description: "Use when splitting work across parallel agents in this repo — read-only fan-out (audit, research, doc review), verification passes, and the one-writer-at-a-time rule that replaces the retired opencode-ensemble team workflow."
---

# Subagent decomposition

How to split work across parallel agents in this repo now that the
`opencode-ensemble` plugin (teams, worktrees, task boards, spaces) is gone.
Parallelism comes from opencode's built-in `subagent` tool; the agents are
defined in `modules/home/opencode/config.nix` under
`my.programs.opencode.agents`.

## Roster

| Agent | Mode | Permissions | Use for |
|---|---|---|---|
| `scout` | subagent | read-only (no edit/bash) | locating files, call sites, subsystem mapping |
| `planner` | subagent | read-only | turning recon into an ordered task list with file ownership + validation steps |
| `builder` | subagent | edit + bash | implementing **one** file-scoped slice |
| `qa` | subagent | edit + bash | writing/running tests, reproducing a failure, reporting verbatim output |
| `reviewer` | subagent | read-only | diff review: correctness, missed tests, risky behavior, scope creep |
| `explore` / `general` | built-in | — | quick search / general multi-step work |

All of them share **your working tree**. There is no worktree isolation and no
merge step, so:

1. **Only one writer (`builder` or `qa`) may run at a time.** Two writers editing
   the same tree is a guaranteed conflict; there is no `team_merge` to untangle it.
2. **Commit between writers.** A slice is done when it is committed — the next
   writer then starts from a clean tree. Never leave a writer's edits uncommitted
   while another starts.
3. Read-only roles (`scout`, `planner`, `reviewer`) may run concurrently, in any
   number the memory budget allows.

## Memory budget (non-negotiable)

Concurrent Nix evaluations/builds have OOM-killed the whole
`opencode-web-*.service` cgroup and dropped the server SSH session. So:

- **Waves of 2**, one `nix` command at a time across all agents.
- Every prompt that may run `nix`/`nixos-rebuild` must carry: *run `free -h`
  first, and wait/report instead of proceeding if available memory is under
  5 Gi*.
- Never have two agents run `nixos-rebuild dry-activate` (or any build) at once.

## Writing a prompt

Subagents start cold — they do not see this conversation. Every prompt needs:

- the **goal** and the exact files/paths in scope (and the ones out of scope);
- the **evidence** you already gathered (file:line, command output);
- the **validation command** they must run;
- **repo rules** that apply (`AGENTS.md`, the relevant module `AGENT.md`,
  staging rule for new files);
- the **output contract**: what to report back (findings list, diff summary,
  test output verbatim, anything unresolved).

Keep it tight; a subagent that has to rediscover context is slower than doing
the work yourself.

## Patterns

**Read-only fan-out (safe, the common case).** Split by disjoint surface — one
file, one doc range, one host, one module — and have every scout return the same
shape (`path:line — finding — severity`). Reconcile yourself; the scouts cannot
see each other.

**Plan then implement.** `planner` returns an ordered task list with file
ownership. You then either implement yourself or hand slices to `builder` one at
a time, committing after each.

**Verify with a separate agent.** `reviewer` reads the diff (not your summary)
and `qa` runs the suite. Independent eyes catch what the author rationalizes.

**Do not fan out** when: the slices share a file; the work is sequential
(schema change → callers → docs); the task is one module; or the coordination
prompt would be longer than the work.

## Anti-patterns

- Spawning a writer to "fix whatever it finds" — scope it to files first.
- Polling for a subagent's result; wait for the message, then read it.
- Trusting a subagent's claim without reading its diff/output.
- Using a subagent to work around context limits: delegate a *slice*, not the
  whole task, or run it serially.

## Upstream repos

There are no "Agent Spaces" any more. When a module's `meta.nix` declares an
`upstream`, work in that repo's own checkout (e.g.
`~/Projects/<repo>`), push, then re-pin the flake input
(`nix flake lock --update-input <flakeInput>`). Never edit a vendored artifact
locally — it is hash-guarded and CI will fail.
