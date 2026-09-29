---
description: Stage, commit, and push nixos-config changes with proper formatting and CI monitoring
---

You are a git workflow assistant. Execute the following steps in order. Do not skip steps. Report the result of each step before proceeding to the next.

## Steps

### 1. Check status and verify gitignore

```bash
git status
git diff --stat
```

Summarise what changed. If the tree is dirty from an in-progress operation (refactor, deploy, etc.), tell the user to finish that first and stop.

**Step 1a: Audit gitignore for untracked files that should be ignored.** Before staging, check whether any untracked files or directories would be committed that belong in `.gitignore`:

```bash
# Show untracked files that are NOT ignored
git ls-files --others --exclude-standard
```

Common files/dirs that should always be ignored but often get missed:

| Pattern | Reason |
|---------|--------|
| `*.db`, `*.sqlite` | Local databases |
| `__pycache__/`, `*.pyc` | Python bytecode |
| `.venv/`, `venv/` | Virtual environments |
| `.mypy_cache/`, `.ruff_cache/` | Linter caches |
| `node_modules/` | JS dependencies |
| `.direnv/` | direnv cache |
| `result`, `result-*` | Nix build symlinks |
| `*.qcow2`, `*.iso` | Disk images |
| `*.log` | Log files |
| `.env`, `.env.*` | Local env files |
| `*.swp`, `*~`, `*.orig` | Editor temp/backup files |
| `.playwright-mcp/` | Playwright MCP artifacts |

If any untracked files match these patterns, **add them to `.gitignore` before staging**:

```bash
# Example: add missed patterns to .gitignore
# Edit .gitignore to include the missing pattern, then re-check
git ls-files --others --exclude-standard
```

**Step 1b: Check for tracked files that should be ignored.** If a file was committed before the gitignore rule existed, it stays tracked even after adding the rule. Detect these:

```bash
# Find tracked files that match current gitignore rules
git ls-files -i --exclude-standard
```

If any appear, remove them from tracking **without deleting the local copy**:

```bash
git rm --cached <file>
```

This is critical — once a file is committed, just adding it to `.gitignore` does NOT stop git from tracking it.

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

**Step 3a: Verify no ignored files snuck in.** After `git add -A`, confirm nothing that should be ignored ended up staged:

```bash
# Check staged files against gitignore rules
git diff --cached --name-only | while read f; do
  git check-ignore "$f" 2>/dev/null && echo "⚠ SHOULD BE IGNORED: $f"
done
```

If any files show up, unstage them with `git reset HEAD -- <file>` and add the pattern to `.gitignore`.

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

**Step 6d: Gitignore health check** — verify nothing that should be ignored is tracked, and no untracked files are missing from `.gitignore`:

```bash
# Check 1: tracked files that match gitignore rules (stale after commit)
STALE=$(git ls-files -i --exclude-standard)
if [ -n "$STALE" ]; then
  echo "⚠ These tracked files match gitignore rules (should be removed from tracking):"
  echo "$STALE"
  echo ""
  echo "Fix: git rm --cached <file> for each"
  exit 1
fi

# Check 2: untracked files that aren't ignored (may need gitignore entry)
UNTRACKED=$(git ls-files --others --exclude-standard)
if [ -n "$UNTRACKED" ]; then
  echo "ℹ Untracked files (will NOT be committed, verify they don't need ignoring):"
  echo "$UNTRACKED"
fi
```

If check 1 finds stale tracked files, remove them from tracking (`git rm --cached`) before pushing. Do **not** delete the files themselves.

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

First, check if this repo even has GitHub Actions configured:

```bash
if [ ! -d .github/workflows ]; then
  echo "No .github/workflows/ directory — skipping CI monitoring."
  exit 0
fi
```

If workflows exist, use the `ci-monitor` CLI (from `packages/ci-monitor/`) to confirm the run registered and block until it completes:

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

## Gotchas

- **`nix fmt -- --check` false positives:** The `--check` flag can report formatting issues even when `nix fmt` produces no diff. Use `nixpkgs-fmt --check` on specific files instead.
- **Gitignore ≠ untracked:** Adding a pattern to `.gitignore` does NOT remove already-tracked files. You must run `git rm --cached <file>` to stop tracking. Until then, `git add -A` will keep staging the file.
- **`git add -A` is aggressive:** It stages everything, including new files that might belong in `.gitignore`. Always run `git ls-files --others --exclude-standard` before staging to catch files that should be ignored first.
- **CI monitoring requires GitHub Actions:** `ci-monitor` assumes `.github/workflows/` exists. If this command is used in a repo without Actions (e.g. a standalone project), Step 8 is skipped automatically. Don't call `ci-monitor` directly if the directory is absent.
- **CI auto-merge races:** The desktop/laptop/server branches get auto-merged to master by CI. If CI merges between your commit and push, you'll get a non-fast-forward rejection. Always `git pull --rebase` before pushing.
- **Amending on auto-merged branches:** If CI creates a merge commit while you're amending, the history gets messy. Prefer `git commit --fixup=<sha>` + `git rebase -i --autosquash` over `git commit --amend`.
- **New module assertions:** When adding a module with test assertions (e.g. `multiplayer.enable -> enable`), ensure the parent option is also set in configs that enable the child. `mkDefault` in profiles may not apply in all evaluation contexts (e.g. VM packages).
- **Never run nix tools in a non-nix repo:** `nix fmt` / `nix flake check` / `statix` / `deadnix` only apply to the nixos-config repo (or another Nix flake). Detect first (Step 0) and skip all nix-specific steps otherwise.
- **Default-branch pushes differ by repo:** "never push to master" is a nixos-config branch-per-host rule. In a generic repo pushing to its default branch is often exactly right — follow the repo's convention.

## RUN LOG

### 2026-09-29 — Step 2/6a/8 gaps hit while shipping a 6-commit series (opencode guidance + `allowedDirs` + waybar + `ebay-sandbox`)

- **Step 2's `nix fmt` is a silent no-op, not a gate** (`git-commit-push.md:65`). It exited 0 and reformatted nothing in the worktree — a staged probe file came back byte-identical — because `nix fmt` runs `pkgs.nixpkgs-fmt` (`modules/flake-parts/formatter.nix:12`) on the flake's store copy. Format explicitly with `nixpkgs-fmt <files>` instead. Recorded as a full entry in `GOTCHAS.md`.
- **The Step 6a snippet fails in two distinct ways** (`git-commit-push.md:153`): (1) `$CHANGED_NIX` is unquoted and the assignment is newline-joined, so under this repo's zsh the whole list is passed as ONE argument → `No such file or directory (os error 2)` reported as if the check passed; (2) `HEAD~1..HEAD` only covers the *last* commit, so in a multi-commit series it silently skips every earlier commit's files. Use explicit paths, or `git diff --name-only <merge-base>..HEAD -- '*.nix'`, and split safely (`xargs -0` / `${=VAR}` in zsh).
- **Step 8's fix table assumes a failing `format-check` is yours** (`git-commit-push.md:244`). CI's format job is repo-wide (`find . -name '*.nix'` → 738 files, excluding only `.git`/`node_modules`/`secrets`/`templates`), so one pre-existing unformatted file reds the gate for every push: this run failed on `modules/home/mail-filter/tag.nix`, untouched by the series and identical to `origin/master`, red since `5496fe3`. Check ownership (`git log -1 -- <file>`) before amending your own commits — an amend cannot fix someone else's file.
- **`ci-monitor list` can be stale and `failed_jobs` conflates `skipped`** (`git-commit-push.md:232`, `git-commit-push.md:237`): after the push, `list` still showed runs from 2026-09-05 while `gh run list -L 6` showed the run started three minutes earlier; the `watch` payload then listed `validate-secrets` and `lint-scripts` under `failed_jobs` although both jobs' `conclusion` was `skipped` (the changes-detector reported `secrets: false` because CI had already fast-forwarded `master` to the pushed tip). Cross-check `gh run list` before concluding CI never started, and triage per-job `conclusion`, not the `failed_jobs` array.
