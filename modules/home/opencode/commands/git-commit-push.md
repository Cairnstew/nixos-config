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

### 2026-10-18 — Step 1b/6a/6c gaps hit while shipping a 4-commit series (build-workarounds + max-free + SillyTavern + secrets)

- **Step 1b's snippet is broken as written**: `git ls-files -i --exclude-standard` exits non-zero with `fatal: ls-files -i must be used with either -o or -c`. The working invocation is `git ls-files -i -c --exclude-standard` (`-c` = consider *tracked* files). The Gotchas table documents the gitignore≠untracked trap but never mentions the flag requirement, so the audit aborts before it can report anything.
- **Step 6a's `HEAD~1..HEAD` again under-covered a multi-commit series**: the naive snippet format-checked 1 file; `git diff --name-only origin/desktop..HEAD -- '*.nix'` with zsh `${=FILES}` splitting checked all 8. This is the 2026-09-29 lesson recurring — treat `<merge-base>..HEAD` as the default form, not an afterthought.
- **Step 6c silently no-ops when `statix`/`deadnix` are absent**: `statix check . && deadnix ...` fails at `command not found`, which the optional step's "if any fail, fix" framing invites you to misreport as a lint finding. Check `command -v statix deadnix` first and say "skipped — not installed, CI's Module Lint covers it".
- **`nix flake check --no-build` can be red for reasons unrelated to the series**: it failed here on `packages.x86_64-linux.nixtests` → suite `opencode-ensemble-vendor-guard` → `error: path '…-vendor' is not valid` (a dead store path baked into the suite script). Reproduced identically on `origin/desktop` via a throwaway `git worktree add /tmp/opencode/fc-base origin/desktop`, proving pre-existing. Do that worktree comparison before amending a series for a flake-check failure you did not cause.

### 2026-10-22 — Step 3's blanket `.age` rule contradicts SECRETS.md; `--no-build` needs a HEAD-side control, not a base-side one

- **Step 3 tells you to unstage `modules/nixos/secrets/*.age`, which would break every secret addition in this repo** (`git-commit-push.md:79`). Encrypted agenix blobs are *meant* to be committed here: `SECRETS.md:8,21,95` documents `modules/nixos/secrets/{name}.age` and gives `git add modules/nixos/secrets/*.age` as the workflow, and 53 `.age` blobs are already tracked. The rule conflates plaintext secrets (never commit) with age-encrypted blobs (commit). Verify before deciding — `head -c 21` shows `age-encryption.org/v1`, and the manifest references it (`modules/nixos/secrets/secrets-manifest.json:183`) — and do not `git reset` a valid `.age` blob just because the filename matches the grep.
- **Step 6b's `nix flake check --no-build` failure needs a HEAD-side control, not the base-side worktree comparison this RUN LOG previously prescribed** (`git-commit-push.md:277`). This run failed on `checks.x86_64-linux.build-desktop` → `error: path '…-source' is not valid`; a worktree `nix eval` of that same check on `origin/server` *succeeded*, which proves nothing because `--no-build` is the mode that breaks on eval-time-only source paths (`GOTCHAS.md:556`), so the two are not like-for-like. The decisive control is `nix eval .#checks.x86_64-linux.build-desktop.drvPath` **on HEAD**: it resolved to a store path here, so the check itself is fine and the `--no-build` red is environmental. Prefer that over the worktree comparison.

### 2026-10-22 — Step 3/8 gaps hit while shipping an obsidian plugin series

- **Step 3's "never stage secrets files" rule contradicts this repo's agenix convention** (`git-commit-push.md:79`): it names `modules/nixos/secrets/*.age` as never-stage, but those blobs are the committed encrypted store (`SECRETS.md:21`, 53 tracked `.age` files), and unstaging a new one breaks the feature (the manifest then references a missing blob). Treat the rule as plaintext-only: stage `.age` ciphertext, and only `git reset HEAD --` a file if its content is actually plaintext.
- **Step 8's `ci-monitor watch` covers exactly ONE run, but a push spawns several** (`git-commit-push.md:233`): the `ac1afa30` push created 5 workflow runs (Smart CI, Merge Per-Host Branch, Local Verification, Module Lint, Format Check); `watch` returned success for just `module-structure` while three others were still `in_progress`. Enumerate every run for the pushed SHA (`gh run list --json ... --jq 'select(.headSha=="<sha>")'`) and block until none are queued/in_progress before declaring CI green.

### 2026-10-27 — Step 7: the repo's auto-push can publish the commits before `git push` runs

- **`git push origin desktop` printed `Everything up-to-date` immediately after two fresh commits** (`git-commit-push.md:207`). Cause: `git-reposync` sets `autoPush = lib.mkDefault true` on a `5m` interval (`modules/nixos/common.nix:445`, `modules/nixos/common.nix:429`), so its user unit pushed both commits while the multi-minute `nix flake check` was still running. This is *not* the stranded-branch failure in `GOTCHAS.md:1601` — the branch was correct and the commits were on the remote. Before treating "Everything up-to-date" as staleness or re-pushing, verify with `git fetch origin && git rev-list --left-right --count origin/<branch>...HEAD` (expect `0 0`) and confirm `git log origin/<branch>` contains the SHA; then go straight to Step 8. Still re-check the branch in the same command as the push (`GOTCHAS.md:1601`) rather than assuming the sync left it alone.

### 2026-11-10 — Step 2/6a: the format gate is a false green when CI omits `--check`

- **Bare `nix fmt` fails outright in a `nixfmt-rfc-style` repo**: it invoked nixfmt 1.5.0 with no paths, which read empty stdin and exited 1 (`Bare invocation of nixfmt is deprecated … unexpected end of input`). Step 2 therefore cannot be treated as a format gate at all. Format changed files with the repo's pinned binary instead: `out=$(nix build .#formatter.<system> --no-link --print-out-paths)`, then `$out/bin/nixfmt -- <files>`.
- **A green `formatting` job does not prove the files are formatted**: `.github/workflows/ci.yml` in `nixos-projectzomboid-servers` runs `"$FMT" -- "$f"`, which formats in place and prints nothing, so the `[ -n "$out" ]` guard passes for unformatted files. Evidence: the pinned `nixfmt --check modpacks/viewpoint.nix` returned `not formatted` (it wants the multiline attrset style) while CI run 42772867664 on the same SHA was `success`. Before trusting Step 6a/8's `format-check` row, read the workflow and confirm it passes `--check`; if it does not, run the check yourself and report the gap rather than relying on CI.

### 2026-11-11 — Step 8: 30+ min queued with zero jobs is an Actions platform outage, not a stuck run

- **Five runs for the pushed SHA sat `queued` ~33 min with `jobs: []`** (`git-commit-push.md:230`). The same five workflows had run to `success` on the `desktop` push ~4 h earlier and nothing under `.github/workflows/` changed, so the code/pipeline was not the cause. Root cause: GitHub **Actions was in `major_outage`** (`https://www.githubstatus.com` → `/api/v2/components.json` showed `Actions -> major_outage`) on 2026-11-11T20:59Z. Check platform status before concluding a run is stuck, re-triggering, or blaming a change: `curl -s https://www.githubstatus.com/api/v2/components.json`. A queued run with zero scheduled jobs means "waiting for a runner"; no `gh run rerun` or empty-commit retry helps during an outage — wait for recovery, when queued runs start automatically.

### 2026-11-11 — Step 8: a `server`→`master` conflict is fixed by merging `origin/master` into the host branch, not rebasing

- **`Merge Per-Host Branch` failed with conflicts in `GOTCHAS.md`, `EFFICIENCY-PROPOSALS.md`, `configurations/nixos/server/default.nix`, and `modules/home/opencode/commands/git-commit-push.md`** (`git-commit-push.md:247`). The fix table says `git pull --rebase origin <branch>`, but that does nothing when you are already on the host branch and the conflict is with `master`, and rebasing an already-pushed host branch would rewrite published history. Correct fix: `git fetch origin && git merge origin/master` on the host branch, resolve conflicts (keep both sides for append-only files like GOTCHAS/EFFICIENCY/RUN LOGs; keep the owning host branch's version for its own config file, e.g. `server/default.nix`), push, and the auto-merge job then fast-forwards master. Verified: after pushing the merge commit, `Merge Per-Host Branch` and every other workflow went green and `origin/master` advanced to the merge.

### 2026-11-12 — a clean tree is a terminal state, not a reason to "not skip steps"

- **"Do not skip steps" has no clean-tree exit** (`git-commit-push.md:5`), and
  Step 1's only stop condition is a dirty in-progress tree
  (`git-commit-push.md:16`). This run started clean (`git status` → "nothing to
  commit", 0 staged, 0 untracked, `0 0` vs `origin/desktop`), so steps 2-8 had
  nothing to act on — `nix fmt` / `git add -A` are no-ops and Step 5 would abort
  with "nothing to commit". State that and stop after Step 1 rather than burning
  the flake-check gate on an empty changeset.
- With no new commit, the useful report is the already-pushed HEAD's health:
  `gh run list --json ... --jq 'select(.headSha=="<sha>")'` showed every
  workflow `success` for `5f9a7c7e`, so nothing needed monitoring.
- Step 1b's snippet (`git-commit-push.md:54`) **and** Step 6d's
  (`git-commit-push.md:183`) still ship the broken
  `git ls-files -i --exclude-standard`; `-c` is required. The 2026-10-18 entry
  records only Step 1b, and append-only self-apply cannot fix either body —
  this needs a real edit of both blocks.

### 2026-11-12 — a red `Merge Per-Host Branch` on the *previous* HEAD is a live blocker Steps 1-8 never surface; preview it with `merge-tree`

- **Lesson:** on a clean tree (Step 1 terminal state, `git-commit-push.md:306`) Steps 2-8 are no-ops, yet the branch can still be unpublishable. `gh run list -L 20 --json databaseId,name,status,conclusion,headSha --jq '.[] | select(.headSha|startswith("<sha>"))'` on HEAD `38d8837a` showed `Merge Per-Host Branch` = **failure** while the other four workflows were green: desktop→master conflicted in `GOTCHAS.md` because both branches appended at EOF. No step reports this, and every later push keeps failing that same job until the conflict is fixed on the host branch — so "clean tree, stop after Step 1" is not the end of the job, it is the point to check the existing HEAD's auto-merge.
- **Fix/practice:** preview the conflict set read-only *before* mutating the worktree with the 2026-11-11 recipe (`git-commit-push.md:304`): `git merge-tree --write-tree origin/master HEAD` listed exactly one conflicted file (`GOTCHAS.md`), matching the CI log, so the resolution was known in advance. Then `git fetch origin && git merge origin/master`, keep both appended sections, `git add GOTCHAS.md`, commit the merge, push — `Merge Per-Host Branch` went green and `origin/master` fast-forwarded to the merge commit (`0 0` vs `origin/desktop`).

### 2026-11-13 — a diverged host branch whose remote holds an obsolete duplicate: merge `-s ours`, never rebase

- **Lesson:** this run opened with `desktop` diverged 8 local / 3 remote, and the
  remote three were not other people's work — they were an *earlier attempt at the
  same theming series*, reset at 12:28:36 and redone locally as a superset
  (`origin/desktop..HEAD` showed "Theme the proxy dashboard, ttyd and Grafana",
  the remote side showed the separate "Generate the proxy dashboard" / "Theme ttyd
  and Grafana" pair). `git diff HEAD origin/desktop -- modules/nixos/{proxy,ttyd,monitoring}`
  was **empty**: identical implementation, and the remote's only unique content was
  content local had deliberately superseded (pre-ratchet `#89b4fa` fallbacks in
  `home/core/git.nix`, the superfile placeholder, older doc status). `origin/master`
  was already at the old tip, so the duplicate was published *and* merged.
- **Why the command's own remedy is wrong here:** Step 1 stops only on a dirty tree
  (`git-commit-push.md:16`), so a clean-but-diverged branch proceeds; Step 7 then
  says a non-fast-forward means "rebased first" (`git-commit-push.md:210`,
  `git-commit-push.md:213`), and the gotcha repeats "Always `git pull --rebase`
  before pushing" (`git-commit-push.md:257`). Replaying the 8 local commits onto the
  3 obsolete duplicates would conflict against work local had already rewritten,
  and it rewrites a published host branch — the same reasoning the 2026-11-11 entry
  applied to host-vs-`master` conflicts.
- **Fix/practice:** when the remote-only commits are an obsolete attempt at work
  local has redone, resolve with `git merge -s ours origin/<branch>` (tree stays
  exactly local HEAD — verified `git diff --stat HEAD^1 HEAD` empty) and push. Because
  the merge brings the remote tip into local history, `Merge Per-Host Branch` runs
  as a fast-forward instead of a duplicate replay. Verified: all five workflows green
  and `origin/master` became the merge commit. Confirm the "obsolete" call first —
  compare the two tips per-file (`git diff -s --stat <base>..HEAD` vs
  `<base>..origin/<branch>` and diff the shared trees); if the remote holds *any*
  unique change, this is the 2026-11-11 merge-with-resolution case, not `-s ours`.
