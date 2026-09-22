---
description: Pull latest master into the local branch and fast-forward the local master ref, stashing local changes and resolving conflicts without committing or pushing
---

You are a git workflow assistant. Execute the following steps in order. Do not skip steps. Report the result of each step before proceeding to the next.

Use this when `gitRepoSync` fails to pull from master due to local changes, or when you need to manually sync master while preserving uncommitted work — e.g. right before `nix run`, whose activate script builds the newest config **from this checkout**. The command leaves the checkout on top of `origin/master` **and** fast-forwards the local `master` ref (which gitRepoSync never updates).

## Steps

### 1. Check current state

```bash
git status
git branch --show-current
```

Report:
- Current branch
- Whether the working tree is clean or dirty
- Whether there are any staged changes

If already on `master` and the tree is clean, just run `git pull --rebase origin master` and stop — no stash needed (the `master` ref is the branch you're on, so the rebase brings it up to date).

### 2. Stash local changes

If the working tree is dirty (unstaged, staged, or untracked changes), stash everything:

```bash
git stash push --include-untracked -m "auto-stash for master sync $(date +%Y-%m-%d_%H:%M)"
```

`--include-untracked` matches gitRepoSync's own stash behavior and prevents a new untracked file from colliding with an incoming master file of the same name.

Verify the stash was created:

```bash
git stash list -1
```

### 3. Fetch and pull master

Fetch the full remote (not just `master`) so every branch's remote-tracking ref is current, then rebase the current branch onto the latest master:

```bash
git fetch origin --prune
git pull --rebase origin master
```

If the rebase fails with conflicts, report them and proceed to step 4.

### 3.5 Sync the local `master` ref

`git pull` updates the **current branch**, but the local `master` ref stays wherever it was. Fast-forward it to `origin/master` — but only when that is a safe move (never discard local-only master commits):

```bash
CURRENT=$(git branch --show-current)
if [ "$CURRENT" != "master" ] && git merge-base --is-ancestor master origin/master 2>/dev/null; then
  git branch -f master origin/master
  echo "local 'master' ref fast-forwarded to origin/master"
elif [ "$CURRENT" = "master" ]; then
  echo "on master: ref already brought up to date by the rebase."
elif ! git merge-base --is-ancestor master origin/master 2>/dev/null; then
  echo "WARNING: local 'master' has commits not on origin/master — leaving it untouched:"
  git log --oneline master ^origin/master 2>/dev/null
fi
```

`git branch -f` cannot move the branch you are currently on — that case is already handled above.

### 4. Resolve conflicts

If there are merge conflicts from the rebase:

```bash
git diff --name-only --diff-filter=U
```

For each conflicted file:
1. Read the file and identify the conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`)
2. Determine the correct resolution — **prefer the incoming master version** for shared infrastructure, **keep the local version** for host-specific config
3. Edit the file to resolve the conflict, removing all conflict markers
4. Stage the resolved file:

```bash
git add <resolved-file>
```

Continue the rebase after resolving all conflicts:

```bash
git rebase --continue
```

After the rebase completes, re-run the step 3.5 master-ref sync (origin/master is unchanged since the fetch, but the current branch has now moved onto it).

If the rebase has multiple conflicted commits, resolve each one in turn.

**If conflicts are too complex to auto-resolve** (e.g., structural refactors on both sides), abort and report:

```bash
git rebase --abort
```

Tell the user which files conflict and suggest manual resolution.

### 5. Unstash local changes

Pop the stash to restore the local work on top of the updated master:

```bash
git stash pop
```

If the stash pop has conflicts with the now-updated master:

```bash
git diff --name-only --diff-filter=U
```

Resolve each conflict the same way as step 4, then stage:

```bash
git add <resolved-file>
```

Do **not** commit. The result should be the local changes applied on top of the latest master, unstaged.

### 6. Verify final state

```bash
git status
git log --oneline -5
```

Confirm the checkout actually sits on the latest master — this is what makes `nix run` build the newest config (`nix run` = `packages.default` = the activate script, which evaluates this checkout):

```bash
git merge-base --is-ancestor origin/master HEAD \
  && echo "OK: checkout includes latest origin/master — nix run will evaluate the newest config" \
  || echo "WARN: checkout is behind origin/master — nix run would evaluate a stale config"
git rev-parse --short master origin/master
```

Report:
- Whether the working tree is clean or has uncommitted local changes
- The last 5 commits (confirm master's latest commits are present)
- Whether any conflicts remain unresolved
- Whether the local `master` ref matches `origin/master` (same hash from the `rev-parse` above)

If everything is clean, confirm the sync succeeded. If there are uncommitted changes, confirm those are the user's original local work restored on top of master.

## Gotchas

- **`gitRepoSync` leaves the local `master` ref stale.** It operates on the per-host branch and merges `origin/master` into it via `--ff-only` (`mergeUpstream`), so it never touches `refs/heads/master`. Observed: `master` was 96 commits behind `origin/master` while the host branch was already at origin/master's tip. Step 3.5 fixes the ref.
- **`nix run` evaluates this checkout, not the remote.** `packages.default` aliases `packages.activate`, which builds `nixosConfigurations.$(hostname)` from the local checkout. Being on top of `origin/master` (verified in step 6) is exactly what guarantees `nix run` rebuilds the newest config. gitRepoSync auto-syncs every 5m; run this command when you need master's latest immediately before `nix run`.
- **Rebase vs merge:** This command uses `pull --rebase` to avoid creating a merge commit. If the user prefers a merge commit, use `git pull origin master` instead.
- **Detached HEAD after abort:** If you abort a rebase mid-way, you may end up on a detached HEAD. Run `git checkout <branch>` to return to your branch.
- **The stash now includes untracked files** (`--include-untracked`), so nothing in the working tree survives into the sync window that could collide with incoming file names.
