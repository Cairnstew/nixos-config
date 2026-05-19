# modules/nixos/gitreposync/AGENT.md

> **Scope:** Git repository sync service
> **Module:** `my.services.gitRepoSync`

---

## Module Purpose

Provides automated git repository synchronization via systemd user timers.
Keeps local repositories up-to-date with remotes using configurable conflict
strategies and optional agenix token injection.

---

## Directory Structure

```
modules/nixos/gitreposync/
├── default.nix      # Import manifest
├── meta.nix         # Machine-readable metadata
├── options.nix      # Option declarations
├── config.nix       # System-level configuration
├── services.nix     # Systemd unit definitions
├── home.nix         # Home-manager integration
├── tests.nix        # Module tests
└── README.md        # Human documentation
```

---

## Key Options

| Option | Purpose |
|--------|---------|
| `enable` | Enable the sync service |
| `user` | User whose systemd session runs the timers |
| `repos.<name>.url` | Remote repository URL |
| `repos.<name>.path` | Local repository path |
| `repos.<name>.interval` | Sync frequency (e.g., `15m`, `1h`) |
| `repos.<name>.conflictStrategy` | How to handle conflicts |
| `repos.<name>.agenix.enable` | Use agenix for token injection |

---

## Conflict Strategies

| Strategy | Behavior | Use Case |
|----------|----------|----------|
| `ff-only` | Only fast-forward, warn on divergence | Safe default |
| `rebase` | Rebase local commits on remote | Linear history |
| `reset-hard` | Discard local changes, mirror remote | Read-only mirror |
| `stash-and-pull` | Stash, pull, pop stash | Config repos with local tweaks |

---

## Agenix Integration

For private repositories, enable agenix to inject GitHub tokens:

```nix
my.services.gitRepoSync.repos.myrepo.agenix = {
  enable = true;
  secretPath = "/run/agenix/github-token-myrepo";
  tokenUser = "oauth2";  # or "x-access-token"
};
```

The token is injected into HTTPS URLs at runtime:
```
https://oauth2:<token>@github.com/user/repo.git
```

---

## Systemd Units

Each repository gets:
- Timer: `git-repo-sync-<name>.timer` - Fires on interval
- Service: `git-repo-sync-<name>.service` - Performs sync

Timers are user units, running in the user's systemd session.

---

## Integration Points

- **systemd**: User timers for periodic sync
- **agenix**: Secure token storage and injection
- **home-manager**: Sets `systemd.user.startServices` for auto-start

---

## Conventions

1. **Use ff-only for important repos**: Never auto-resolve conflicts
2. **Use reset-hard for mirrors**: Treat as read-only
3. **Check divergence regularly**: Timers log warnings on conflict
4. **Keep intervals reasonable**: Balance freshness vs. resources

---

## See Also

- `modules/home/opencode/skills/git-repo-management.md` - OpenCode skill
- `modules/home/core/git.nix` - Git configuration
- [Agenix documentation](https://github.com/ryantm/agenix)
