# Git Repository Sync

Keep local git repositories automatically synced with remotes using systemd
user timers.

## Features

- **Per-repo timers** — each repository gets its own service + timer.
- **Conflict strategies** — `ff-only`, `rebase`, `reset-hard`, `stash-and-pull`.
- **Agenix integration** — inject GitHub fine-grained tokens at runtime without
  storing them in the Nix store.
- **Branch-aware** — track specific branches or fetch all refs.
- **Bare clone support** — mirror repositories without a working tree.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.gitRepoSync.enable` | `false` | Enable the sync service |
| `my.services.gitRepoSync.user` | — | User that owns the timers |
| `my.services.gitRepoSync.repos.<name>.url` | — | Remote URL (https or ssh) |
| `my.services.gitRepoSync.repos.<name>.path` | — | Absolute local path |
| `my.services.gitRepoSync.repos.<name>.branches` | `[]` | Branches to track (empty = current branch) |
| `my.services.gitRepoSync.repos.<name>.conflictStrategy` | `"ff-only"` | How to integrate remote changes |
| `my.services.gitRepoSync.repos.<name>.interval` | `"15m"` | Sync interval |
| `my.services.gitRepoSync.repos.<name>.agenix.enable` | `false` | Enable token injection |
| `my.services.gitRepoSync.repos.<name>.agenix.secretPath` | `/run/agenix/github-token-<name>` | Path to decrypted token |

## Usage Example

```nix
my.services.gitRepoSync = {
  enable = true;
  user = "alice";
  repos = {
    dotfiles = {
      url      = "https://github.com/alice/dotfiles.git";
      path     = "/home/alice/.dotfiles";
      interval = "1h";
      branches = [ "main" ];
    };
  };
};
```

## Conflict Strategies

| Strategy | Behaviour |
|----------|-----------|
| `ff-only` | Only merge if fast-forward is possible. Safest default. |
| `rebase` | Rebase local commits. Aborts cleanly on conflict. |
| `reset-hard` | Destructive — discards all local changes. Good for mirrors. |
| `stash-and-pull` | Stashes local work, fast-forwards, pops stash. |

## Per-Host Branch Workflow

This flake uses a **branch-per-host rollout** model for the `nixos-config` repo:

```
host commit ──autoPush──▶ origin/<hostname> ──merge-per-host.yml──▶ master ──mergeUpstream──▶ other host branches
```

1. **Host → own branch**: configured in `modules/nixos/common.nix` with
   `branch = config.networking.hostName`, `autoPush = true`, and
   `mergeUpstream = "master"`. On each tick the service stays on the host
   branch, attempts a fast-forward merge of `master`, then pushes committed
   changes to `origin/<hostname>`. (It pushes commits — it does not commit.)

2. **CI checks + auto-merge to master**: `.github/workflows/merge-per-host.yml`
   triggers on push to any per-host branch. It validates the affected host
   (`nix build ".#nixosConfigurations.<host>.config.system.build.toplevel" --dry-run`),
   then creates/updates a PR `<host> → master` and enables auto-merge.
   `smart-ci.yml` runs its path-aware checks on the PR, so auto-merge only
   lands once they are green.

3. **Master full CI**: on push to `master`, `smart-ci.yml` runs everything
   (eval all hosts, builds, tests, Cachix caching).

4. **Other hosts pull**: each other host's sync merges `master` into its own
   branch via `mergeUpstream` (always `--ff-only`).

### ff-only caveats

- `mergeUpstream` is **hard-coded `--ff-only`** (see `services.nix`) — it does
  not honour `conflictStrategy`. If the merge cannot fast-forward it is skipped
  and logged as `SKIP — upstream merge not fast-forward`.
- A host with its **own unmerged commits** cannot fast-forward to `master` and
  goes stale until its own PR lands. Once the PR merges, `master` contains that
  host's commits, so the next sync fast-forwards cleanly and picks up everyone
  else's changes too. This is intended rollout-gating behaviour, not a bug.
- A **dirty working tree** also blocks the ff-only merge — uncommitted edits to
  files that also changed upstream cause the merge to be skipped. Commit or
  stash them first.

### Maintenance when adding a new host

- Add the new hostname to `on.push.branches` in
  `.github/workflows/merge-per-host.yml`. Hosts not listed are pushed by
  `autoPush` but are never merged into `master`.
- The `branch` / `mergeUpstream` defaults in `common.nix` follow the hostname
  automatically — no per-host config needed.

## Testing

Run the smoke test manually:

```bash
systemctl --user start git-repo-sync-smoke-test
journalctl --user -u git-repo-sync-smoke-test -n 30 --no-pager
```
