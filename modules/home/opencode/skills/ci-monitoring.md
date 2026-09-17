# CI Monitoring

> Skill for monitoring GitHub Actions CI runs with structured JSON output

## Overview

The `ci-monitor` tool wraps `gh` CLI commands into a single blocking, JSON-returning operation. It exists because:

- The **GitHub MCP server** provides one-shot API calls (list/get workflow runs) but does not block or poll — every call returns immediately with current state.
- **Manual `gh` commands** (`gh run list`, `gh run watch`, `gh run view`) work but require the agent to parse CLI output, manage sleep-loops, and handle rate limits.
- **`ci-monitor`** does all three: it blocks until the run reaches a terminal state (delegating polling/backoff to `gh run watch`), returns clean structured JSON, and auto-detects the repo and run ID from the current git state.

## Quick Reference

| Action | What it does | Example |
|--------|-------------|---------|
| `action=list` | List 10 most recent runs on the current branch | `ci-monitor action=list` |
| `action=watch` | Block until a run completes, then return results | `ci-monitor action=watch` |
| `action=view` | View details for a specific run (including failure logs) | `ci-monitor action=view run_id=12345` |

## When to Use

### `action=list` — Confirm a run started

Use right after a push to confirm the CI run registered and is in progress:

```
ci-monitor action=list
```

### `action=watch` — Block until CI is terminal

Use before proceeding to a dependent task (e.g., before deploy, before starting another build):

```
ci-monitor action=watch
```

The tool matches runs by commit SHA (not "latest run on branch") to avoid picking up stale runs. It retries up to 8 times (80s max) if the run hasn't registered yet.

### `action=view` — Diagnose a specific run

Use to inspect a specific run, including old/past runs unrelated to the current push:

```
ci-monitor action=view run_id=12345
```

## Timeout Guidance

The default timeout is **1800 seconds** (30 minutes). This covers full system builds (`nix build .#laptop`, `.#server`, `.#wsl`) which can take 15–30+ minutes.

| Scenario | Recommended timeout |
|----------|-------------------|
| Format-check only | `timeout=120` |
| Eval-check + format-check | `timeout=300` |
| Full system build | `timeout=1800` (default) |
| Unknown / first time | Use default (1800) |

On a `timeout` error, either check the `url` field manually or re-invoke with a longer timeout.

## Interpreting Results

All actions return structured JSON. The key fields:

| Field | Meaning |
|-------|---------|
| `conclusion` | `"success"`, `"failure"`, `"cancelled"`, `"timed_out"` |
| `failed_jobs` | List of job names that did not succeed |
| `log_excerpt` | Last 2000 chars of failed job logs (null on success) |
| `duration_seconds` | Wall-clock time from start to completion |

### Conclusion meanings

- **`success`** → Safe to proceed. `log_excerpt` is `null`.
- **`failure`** → Inspect `failed_jobs` and `log_excerpt` to diagnose.
- **`cancelled`** → Someone cancelled the run. Investigate before re-pushing.
- **`timed_out`** → The GitHub Actions job timed out. Check if the build is genuinely slow or stuck.

## Common CI Failures and Fixes

| Failure | Fix |
|---------|-----|
| `format-check` fails | Run `nix fmt`, recommit |
| `eval-check` fails | Nix syntax/import error — inspect `log_excerpt` for the specific file and error |
| `lint-check` fails | statix/deadnix warnings — inspect `log_excerpt` for the specific file and warning |
| `auto-pr` fails (merge conflict) | Merge master into your branch, push again |
| `auto-pr` fails (format check) | Run `nix fmt` on your branch, push again |

## Integration with Git Workflow

```
git-commit-push
  → ci-monitor action=list     # confirm run registered
  → ci-monitor action=watch    # block until terminal
  → on failure: ci-monitor action=view run_id=<id>  # diagnose
```

### After pushing

```bash
# Confirm the run started
ci-monitor action=list

# Block until it completes
ci-monitor action=watch
```

### Diagnosing a failure

```bash
# Get full details + logs for a specific run
ci-monitor action=view run_id=12345
```

### Checking an old run

```bash
# View any past run by ID — no SHA matching needed
ci-monitor action=view run_id=67890
```

## Race Condition Handling

The tool matches runs by commit SHA, not "latest run on branch," to avoid picking up a stale run from a previous push. If the run hasn't registered yet (GitHub Actions lag), the tool retries up to 8 times with 10-second intervals (80s max). If still not found, it returns an explicit `run_not_found` error with the SHA and branch rather than hanging.

## See Also

- `skills/git-staging-commit-push.md` — Full git workflow including CI monitoring steps
- `skills/git-repo-management.md` — Branch-per-host model
