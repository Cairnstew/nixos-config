# Git Staging, Commit & Push Workflow

> Skill for staging, committing, and pushing changes with proper formatting and CI monitoring in nixos-config

## Overview

This skill covers the local git workflow for nixos-config: staging changes, writing properly formatted commit messages, pushing to host branches, and monitoring CI results. It works within the branch-per-host model documented in `skills/git-repo-management.md`.

## Quick Reference

```bash
# 1. Check status
git status

# 2. Format all .nix files
nix fmt

# 3. Stage changes
git add -A

# 4. Commit with prefix tag
git commit -m "[nix] description of change"

# 5. Push to current host branch
git push

# 6. Monitor CI
gh run list --branch=$(git branch --show-current) --limit=5
```

## Step-by-Step Workflow

### Step 1: Check Working Tree Status

```bash
git status
git diff --stat
```

Ensure you understand what changed and why. If the tree is dirty from an in-progress operation (e.g., a refactor or deploy), finish that first.

### Step 2: Format Nix Files

Always format before committing to avoid CI format-check failures:

```bash
nix fmt
```

This runs `nixpkgs-fmt` on all `.nix` files. The formatter is pinned in the flake as `formatter.x86_64-linux`.

**Note:** A few files in `templates/*.nix` may have pre-existing format issues that aren't your responsibility. If `nix fmt -- --check` shows failures only in templates, that's expected.

### Step 3: Review Changes

```bash
git diff
git diff --cached
```

Check that:
- Only intended files changed
- No secrets or sensitive data are exposed
- Changes are logically complete
- Comments explain *why* changes are made (per repo convention)

### Step 4: Stage Changes

```bash
# Stage everything
git add -A

# Or stage specific files
git add path/to/file.nix
```

**Never stage secrets files** (`modules/nixos/secrets/*.age`, plaintext tokens, etc.).

### Step 5: Commit with Proper Format

#### Commit Message Format

```
[prefix] Short description (≤72 chars)

Optional body (wrap at 80 chars):
- Explain WHY, not just WHAT
- Reference related issues or findings
```

#### Prefix Tags

Use the appropriate prefix based on what changed:

| Prefix | Use For |
|--------|---------|
| `[nix]` | General NixOS/Nix changes |
| `[home]` | Home Manager configuration |
| `[opencode]` | OpenCode skills, commands, config |
| `[ci]` | GitHub Actions workflows |
| `[flake]` | flake.nix, flake inputs, flake-parts |
| `[deploy]` | Deployment configs, justfile recipes |
| `[iso]` | ISO/bootable image changes |
| `[ventoy]` | Ventoy multi-boot system |
| `[secrets]` | agenix secret management |
| `[docs]` | Documentation only |
| `[test]` | Tests and test infrastructure |
| `[refactor]` | Code restructuring (no behavior change) |
| `[fix]` | Bug fix |
| `[feat]` | New feature |
| `[chore]` | Maintenance, dependency updates |

#### Examples

```bash
# Simple change
git commit -m "[nix] Enable bluetooth on laptop"

# With body explaining why
git commit -m "[nix] Add memory limit to opencode-web service

Prevents OOM kills when running ensemble commands.
Sets MemorySwapMax=4G and opts out of systemd-oomd."

# Multi-file refactor
git commit -m "[refactor] Consolidate host-specific audio config into workstation profile

Moves duplicated pipewire settings from laptop/desktop/default.nix
into profiles/system/workstation.nix to reduce duplication."

# CI change
git commit -m "[ci] Add path filter for format-check workflow"
```

### Step 6: Push to Host Branch

Push to the current branch (which should be your host branch):

```bash
git push
```

This triggers the **branch-per-host CI pipeline**:

```
push to origin/<host> → merge-per-host.yml validates → auto-PR to master
```

**Important:** Never push directly to `master`. Always push to your host branch and let CI create the PR.

### Step 7: Monitor CI

After pushing, check the CI status:

```bash
# List recent runs on current branch
gh run list --branch=$(git branch --show-current) --limit=5

# Watch a specific run
gh run watch

# View failed run details
gh run view <run-id>
```

#### What CI Does

| Workflow | Trigger | What It Checks |
|----------|---------|----------------|
| `merge-per-host.yml` | Push to host branches | Validates config, creates PR to master |
| `smart-ci.yml` | PR/push to main/master | Path-aware checks (only runs relevant checks) |
| `format-check.yml` | Changes to `**/*.nix` | `nixpkgs-fmt --check` |
| `pr-checks.yml` | Any PR | Eval-check all hosts + lint-checks |
| `local-verify.yml` | Non-main/master push | act-compatible local verification |

#### Common CI Failures and Fixes

| Failure | Fix |
|---------|-----|
| `format-check` fails | Run `nix fmt` and recommit |
| `eval-check` fails | Check nix syntax, missing imports, or undefined options |
| `lint-check` fails | Fix statix/deadnix warnings in changed files |
| `module-lint` fails | Ensure `default.nix` is import-only, `meta.nix` present |

## Handling Multiple Logical Changes

If you have several unrelated changes, commit them separately:

```bash
# Stage and commit change 1
git add path/to/file1.nix
git commit -m "[home] Update ghostty theme settings"

# Stage and commit change 2
git add path/to/file2.nix path/to/file3.nix
git commit -m "[nix] Fix tailscale firewall rules"
```

This creates atomic commits that are easy to review, revert, or bisect.

## Pre-Commit Checks

Before committing, run these optional checks:

```bash
# Quick flake check (eval only, no builds)
nix flake check --no-build

# Lint changed .nix files
nix-lint path/to/changed-file.nix

# Build current host (takes longer)
nix build .#nixosConfigurations.$(hostname).config.system.build.toplevel
```

## Undoing Changes

### Unstage a file

```bash
git restore --staged path/to/file.nix
```

### Discard uncommitted changes

```bash
git restore path/to/file.nix
```

### Amend the last commit (before push)

```bash
git commit --amend -m "[nix] Updated description"
```

### Revert a pushed commit

```bash
git revert <commit-hash>
git push
```

## Syncing with Other Host Branches

If your host branch is behind master (e.g., another host merged first):

```bash
git fetch origin
git rebase origin/master
git push
```

The `gitRepoSync` service handles this automatically via `mergeUpstream = "ff-only"`, but you may need to do it manually if there are conflicts.

## Troubleshooting

### "Permission denied" on push

Ensure SSH keys are configured or use HTTPS with a valid token.

### CI doesn't trigger

- Check the branch name is in the workflow's `on.push.branches` list
- Verify the workflow file isn't disabled or has syntax errors

### Format check fails but `nix fmt` passes

- You may have unstaged formatting changes. Run `git diff` to check.
- Some templates have pre-existing format issues (known, not your problem).

### Eval check fails after clean local build

- CI may be evaluating a different host or using different inputs
- Check the CI logs for the specific host that failed
- Run `nix eval .#nixosConfigurations.<host>.config.system.build.toplevel` locally

## See Also

- `skills/git-repo-management.md` — Branch-per-host model, gitRepoSync service, conflict strategies
- `skills/deploy-workflow.md` — Deployment and activation workflow
- `AGENTS.md` §9 Style & Lint — Formatting rules and conventions
- `.github/workflows/README.md` — Full CI pipeline documentation
