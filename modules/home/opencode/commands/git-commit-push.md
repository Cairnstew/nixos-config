---
description: Stage, commit, and push nixos-config changes with proper formatting and CI monitoring
---

You are a git workflow assistant. Execute the following steps in order. Do not skip steps. Report the result of each step before proceeding to the next.

## Steps

### 1. Check status

```bash
git status
git diff --stat
```

Summarise what changed. If the tree is dirty from an in-progress operation (refactor, deploy, etc.), tell the user to finish that first and stop.

### 2. Format nix files

```bash
nix fmt
```

This runs `nixpkgs-fmt` on all `.nix files. Always do this before committing to avoid CI format-check failures.

### 3. Stage changes

```bash
git add -A
```

Never stage secrets files (`modules/nixos/secrets/*.age`, plaintext tokens, etc.). If any secrets files appear in the diff, `git reset` them and warn the user.

### 4. Review the staged diff

```bash
git diff --cached
```

Check that:
- Only intended files are staged
- No secrets or sensitive data are exposed
- Changes are logically complete
- Comments explain *why* changes are made (per repo convention)

### 5. Commit with prefix tag

Use the appropriate prefix based on what changed:

| Prefix | Use For |
|--------|---------|
| `[nix]` | General NixOS/Nix changes |
| `[home]` | Home Manager configuration |
| `[opencode]` | OpenCode skills, commands, config |
| `[ci]` | GitHub Actions workflows |
| `[flake]` | flake.nix, flake inputs, flake-parts |
| `[deploy]` | Deployment configs, justfile recipes |
| `[secrets]` | agenix secret management |
| `[docs]` | Documentation only |
| `[test]` | Tests and test infrastructure |
| `[refactor]` | Code restructuring (no behavior change) |
| `[fix]` | Bug fix |
| `[feat]` | New feature |
| `[chore]` | Maintenance, dependency updates |

Commit message format:

```
[prefix] Short description (≤72 chars)

Optional body (wrap at 80 chars):
- Explain WHY, not just WHAT
```

If there are multiple logically separate changes, commit them separately (one commit per logical change).

### 6. Local validation (pre-push gate)

Run these three checks. If any fail, fix the issue, amend the commit, and re-run the checks before proceeding.

```bash
nix fmt -- --check
nix-lint
nix flake check --no-build
```

| Check | What it catches |
|-------|-----------------|
| `nix fmt -- --check` | Formatting issues that would fail CI format-check |
| `nix-lint` | statix antipatterns and deadnix unused code |
| `nix flake check --no-build` | Eval errors, missing imports, undefined options |

All three must pass before pushing. If `nix fmt -- --check` fails, run `nix fmt` to fix, then `git add -A && git commit --amend --no-edit` and re-check.

### 7. Push to current branch

```bash
git push
```

Never push directly to `master`. Always push to the current host branch and let CI create the auto-PR.

### 8. Monitor CI

```bash
gh run list --branch=$(git branch --show-current) --limit=5
```

Report the CI status. If any checks failed, suggest the fix:

| Failure | Fix |
|---------|-----|
| `format-check` fails | Run `nix fmt` and recommit |
| `eval-check` fails | Check nix syntax, missing imports, or undefined options |
| `lint-check` fails | Fix statix/deadnix warnings in changed files |
| `auto-pr` fails (merge conflict) | Merge master into your branch, push again |
