---
description: Stage, commit, and push changes. Detects whether the repo is nixos-config (formatting, flake checks, branch-per-host rules, ci-monitor) or any other git repo (lean generic workflow)
---

You are a git workflow assistant. Execute the following steps in order. Do not skip steps. Report the result of each step before proceeding to the next.

## Step 0: Determine which repo we are in

```bash
git remote get-url origin
git rev-parse --show-toplevel
```

Set a mental flag `IS_NIXOS_CONFIG` — true when the checkout is this NixOS configuration repo (remote ends in `nixos-config`, or the tree contains `flake.nix` + `modules/nixos/`). Otherwise it is a **generic repo** and every nix-specific step below is skipped.

For generic repos, check the repo's own conventions instead:

```bash
git log --oneline -5
ls Makefile justfile package.json Cargo.toml go.mod pyproject.toml 2>/dev/null
```

Note whether commits use prefixes (e.g. conventional commits `feat:`/`fix:`) and what test/lint commands exist, so steps 5–6 match the repo.

## Step 1: Check status

```bash
git status
git diff --stat
```

Summarise what changed. If the tree is dirty from an in-progress operation (refactor, deploy, etc.), tell the user to finish that first and stop.

## Step 2: Format

**nixos-config only:**

```bash
nix fmt
```

This runs `nixpkgs-fmt` on all `.nix` files. Always do this before committing to avoid CI format-check failures.

**Generic repos:** do not run `nix fmt`. Run the repo's own formatter if it clearly has one (e.g. `go fmt`, `cargo fmt`, `npx prettier --write .`, `ruff format .`) and formatting is part of its workflow; otherwise skip silently.

## Step 3: Stage changes

```bash
git add -A
```

**Never stage secrets files** — plaintext tokens, `.env`, `*.age`, credential files, etc. After staging, verify:

```bash
git diff --cached --name-only | grep -E '(\.env$|\.age$|secrets/|token|secret|credential|known_hosts)' || echo "No secrets staged"
```

If any secrets files appear, `git reset HEAD -- <file>` them and warn the user.

## Step 4: Review the staged diff

```bash
git diff --cached
```

Check that:
- Only intended files are staged
- No secrets or sensitive data are exposed
- Changes are logically complete
- Comments explain *why* changes are made (per repo convention)

## Step 5: Commit with prefix tag

Use the appropriate prefix based on what changed:

**nixos-config — repo-specific prefixes:**

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

**Generic repos — match the repo's own convention** (e.g. conventional commits `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`, `ci:`, or no prefix if the log shows none).

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

## Step 6: Local validation (pre-push gate)

Run these checks. If any fail, fix, amend, and re-check before pushing.

**Step 6a: Formatting — nixos-config only.** Run `nixpkgs-fmt --check` on changed files (faster and more reliable than `nix fmt -- --check` which can report false positives):

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

**Step 6b: Flake check — nixos-config only.** Catches eval errors, missing imports, undefined options:

```bash
nix flake check --no-build
```

If it fails with a failed assertion, the new module likely sets an option without enabling its parent. Fix the config and amend.

**Step 6c: Lint — nixos-config only** (optional, catches statix antipatterns and deadnix unused code):

```bash
statix check . && deadnix --no-lambda-pattern-names .
```

**Generic repos:** run the repo's own test/lint/build command if one exists and is reasonably fast (e.g. `cargo test`, `go test ./...`, `npm test`, `pytest`, project `Makefile`/`justfile` targets). If none exists or it would take too long, say so and skip — do not invent checks.

## Step 7: Push to current branch

**Always specify the remote branch explicitly** — CI auto-merges can confuse tracking:

```bash
git push origin $(git branch --show-current)
```

If rejected with "non-fast-forward", remote changed while you were working. Rebase first:

```bash
git pull --rebase origin $(git branch --show-current)
git push origin $(git branch --show-current)
```

**nixos-config only:** never push directly to `master` — always push to the current host branch and let CI create the auto-PR. **Generic repos:** match the repo's own workflow — pushing straight to its default branch is normal there; only branch off if the repo's contribution workflow (PRs) requires it.

## Step 8: Monitor CI

**nixos-config only:** use the `ci-monitor` CLI (from `packages/ci-monitor/`) to confirm the run registered and block until it completes:

1. **Confirm run started:** `ci-monitor list`
2. **Block until terminal:** `ci-monitor watch`

If the watch returns a failure conclusion, inspect the result:

- `failed_jobs` — which jobs didn't pass
- `log_excerpt` — last 2000 chars of the failed job logs

Suggest the fix based on the failure:

| Failure | Fix |
|---------|-----|
| `format-check` fails | Run `nixpkgs-fmt` on the reported files, amend, push |
| `eval-check` fails | Check nix syntax, missing imports, or undefined options |
| `lint-check` fails | Fix statix/deadnix warnings in changed files |
| `auto-pr` fails (merge conflict) | `git pull --rebase origin <branch>`, push again |

If `ci-monitor action=watch` returns a `timeout` error, check the `url` field manually or re-invoke with a longer `timeout`.

**Generic repos:** if the remote is GitHub/GitLab and the repo has CI, report the push and optionally check it with `gh run list` / the platform's equivalent. If there is no CI or it is not reachable, just confirm the push succeeded.

## Gotchas

- **`nix fmt -- --check` false positives (nixos-config):** The `--check` flag can report formatting issues even when `nix fmt` produces no diff. Use `nixpkgs-fmt --check` on specific files instead.
- **Never run nix tools in a non-nix repo:** `nix fmt` / `nix flake check` / `statix` / `deadnix` only apply to the nixos-config repo (or another Nix flake). Detect first (Step 0) and skip all nix-specific steps otherwise.
- **CI auto-merge races (nixos-config):** The desktop/laptop/server branches get auto-merged to master by CI. If CI merges between your commit and push, you'll get a non-fast-forward rejection. Always `git pull --rebase` before pushing.
- **Amending on auto-merged branches (nixos-config):** If CI creates a merge commit while you're amending, the history gets messy. Prefer `git commit --fixup=<sha>` + `git rebase -i --autosquash` over `git commit --amend`.
- **New module assertions (nixos-config):** When adding a module with test assertions (e.g. `multiplayer.enable -> enable`), ensure the parent option is also set in configs that enable the child. `mkDefault` in profiles may not apply in all evaluation contexts (e.g. VM packages).
- **Default-branch pushes differ by repo:** "never push to master" is a nixos-config branch-per-host rule. In a generic repo pushing to its default branch is often exactly right — follow the repo's convention.
