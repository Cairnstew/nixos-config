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

## Testing

Run the smoke test manually:

```bash
systemctl --user start git-repo-sync-smoke-test
journalctl --user -u git-repo-sync-smoke-test -n 30 --no-pager
```
