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

This runs `nixpkgs-fmt` on all `.nix` files. Always do this before committing to avoid CI format-check failures.

### 3. Stage changes

```bash
git add -A
```

**Never stage secrets files** (`modules/nixos/secrets/*.age`, plaintext tokens, etc.). After staging, verify:

```bash
git diff --cached --name-only | grep -E '(secrets/.*\.age|\.env|token|secret)' || echo "No secrets staged"
```

If any secrets files appear, `git reset HEAD -- <file>` them and warn the user.

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

**Multiple logical changes:** If the staged diff contains multiple unrelated features, commit them separately:

1. `git reset` (unstages everything, keeps workdir)
2. Stage the first logical group: `git add <files>`
3. Commit it
4. Repeat for each group

### 6. Local validation (pre-push gate)

Run these checks. If any fail, fix, amend, and re-check before pushing.

**Step 6a: Formatting** — Run `nixpkgs-fmt --check` on changed files (faster and more reliable than `nix fmt -- --check` which can report false positives):

```bash
CHANGED_NIX=$(git diff --name-only HEAD~1..HEAD -- '*.nix')
if [ -n "$CHANGED_NIX" ]; then
  nixpkgs-fmt --check $CHANGED_NIX
fi
```

If formatting fails, fix with `nixpkgs-fmt <files>`, then amend:

```bash
git add -A && git commit --amend --no-edit
```

**Step 6b: Flake check** — catches eval errors, missing imports, undefined options:

```bash
nix flake check --no-build
```

If it fails with a failed assertion, the new module likely sets an option without enabling its parent. Fix the config and amend.

**Step 6c: Lint** (optional, catches statix antipatterns and deadnix unused code):

```bash
statix check . && deadnix --no-lambda-pattern-names .
```

### 7. Push to current branch

**Always specify the remote branch explicitly** — CI auto-merges can confuse tracking:

```bash
git push origin $(git branch --show-current)
```

If rejected with "non-fast-forward", CI auto-merged while you were working. Rebase first:

```bash
git pull --rebase origin $(git branch --show-current)
git push origin $(git branch --show-current)
```

**Never push directly to `master`.** Always push to the current host branch and let CI create the auto-PR.

### 8. Monitor CI

```bash
gh run list --branch=$(git branch --show-current) --limit=5
```

Report the CI status. The **push-triggered** checks (not `pull_request` events) are what matter. If any failed, suggest the fix:

| Failure | Fix |
|---------|-----|
| `format-check` fails | Run `nixpkgs-fmt` on the reported files, amend, push |
| `eval-check` fails | Check nix syntax, missing imports, or undefined options |
| `lint-check` fails | Fix statix/deadnix warnings in changed files |
| `auto-pr` fails (merge conflict) | `git pull --rebase origin <branch>`, push again |

## Gotchas

- **`nix fmt -- --check` false positives:** The `--check` flag can report formatting issues even when `nix fmt` produces no diff. Use `nixpkgs-fmt --check` on specific files instead.
- **CI auto-merge races:** The desktop/laptop/server branches get auto-merged to master by CI. If CI merges between your commit and push, you'll get a non-fast-forward rejection. Always `git pull --rebase` before pushing.
- **Amending on auto-merged branches:** If CI creates a merge commit while you're amending, the history gets messy. Prefer `git commit --fixup=<sha>` + `git rebase -i --autosquash` over `git commit --amend`.
- **New module assertions:** When adding a module with test assertions (e.g. `multiplayer.enable -> enable`), ensure the parent option is also set in configs that enable the child. `mkDefault` in profiles may not apply in all evaluation contexts (e.g. VM packages).
