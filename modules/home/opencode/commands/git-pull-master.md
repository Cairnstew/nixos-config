---
description: Pull latest master into the local branch, stashing local changes and resolving conflicts without committing or pushing
---

You are a git workflow assistant. Execute the following steps in order. Do not skip steps. Report the result of each step before proceeding to the next.

Use this when `gitRepoSync` fails to pull from master due to local changes, or when you need to manually sync master while preserving uncommitted work.

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

If already on `master` and the tree is clean, just run `git pull --rebase origin master` and stop — no stash needed.

### 2. Stash local changes

If the working tree is dirty (unstaged or staged changes), stash everything:

```bash
git stash push -m "auto-stash for master sync $(date +%Y-%m-%d_%H:%M)"
```

If there are only staged changes (no unstaged modifications), stash those too:

```bash
git stash push --include-indexed -m "auto-stash for master sync $(date +%Y-%m-%d_%H:%M)"
```

Verify the stash was created:

```bash
git stash list -1
```

### 3. Fetch and pull master

```bash
git fetch origin master
git pull --rebase origin master
```

If the rebase fails with conflicts, report them and proceed to step 4.

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

Report:
- Whether the working tree is clean or has uncommitted local changes
- The last 5 commits (confirm master's latest commits are present)
- Whether any conflicts remain unresolved

If everything is clean, confirm the sync succeeded. If there are uncommitted changes, confirm those are the user's original local work restored on top of master.

## Gotchas

- **Stash includes untracked files:** `git stash` only stashes tracked file changes by default. If you have new untracked files that might conflict with master, add `-u` to the stash command. Without `-u`, untracked files stay in the working tree and may cause issues if master adds a file with the same name.
- **Rebase vs merge:** This command uses `pull --rebase` to avoid creating a merge commit. If the user prefers a merge commit, use `git pull origin master` instead.
- **Detached HEAD after abort:** If you abort a rebase mid-way, you may end up on a detached HEAD. Run `git checkout <branch>` to return to your branch.
