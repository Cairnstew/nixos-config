# Git Repository Management

> Skill for managing git repositories in NixOS configurations

## Overview

This skill covers git repository management patterns used in this NixOS
configuration, including the automated git repository sync service and
common git workflows.

## Git Repository Sync Service

The `my.services.gitRepoSync` module provides automated git repository
synchronization via systemd user timers.

### Configuration

```nix
my.services.gitRepoSync = {
  enable = true;
  user = "seanc";
  repos = {
    dotfiles = {
      url = "https://github.com/seanc/dotfiles.git";
      path = "/home/seanc/.dotfiles";
      interval = "1h";
      conflictStrategy = "ff-only";
    };
  };
};
```

### Conflict Strategies

| Strategy | Use Case |
|----------|----------|
| `ff-only` | Safe default - only fast-forward, warn on divergence |
| `rebase` | Keep linear history, abort on conflict |
| `reset-hard` | Mirror mode - destructive, discards local changes |
| `stash-and-pull` | Stash changes, pull, pop stash - good for configs |

### Key Options

- `interval`: Sync frequency (systemd time span, e.g., `15m`, `1h`)
- `branches`: Specific branches to track (empty = all)
- `autoPull`: Whether to integrate changes or just fetch
- `fetchPrune`: Remove stale remote-tracking refs
- `agenix.enable`: Use agenix for GitHub token injection

## Common Git Tasks in This Repo

### Adding a New Host Configuration

1. Create directory: `mkdir configurations/nixos/myhost/`
2. Create `default.nix` with host configuration
3. Generate hardware config if needed: `nixos-generate-config --show-hardware-config > hardware-configuration.nix`
4. Commit and push

### Updating Flake Inputs

```bash
# Update all inputs
nix flake update

# Update specific inputs
nix flake lock --update-input nixpkgs --update-input home-manager
```

### Formatting

```bash
nix fmt  # Runs nixpkgs-fmt on all .nix files
```

### Testing

```bash
# Build and test current host
nix run

# Test specific host
nix run .#test run <hostname>

# List all hosts
nix run .#test list
```

### Secrets Management

Secrets are managed with agenix:

1. Edit `secrets/secrets.nix` to declare secrets and keys
2. Run `agenix -e secret-name` to encrypt
3. Reference in configs: `config.age.secrets.<name>.path`

Never commit plaintext secrets or reference secret paths directly without
checking if the secret exists first.

## Git Configuration in Home Manager

Git is configured in `modules/home/core/git.nix`:

- User info from `flake.config.me`
- Aliases: `co`, `ci`, `s`, `b`, `pu`, etc.
- Delta for better diffs
- Lazygit for TUI

## Best Practices

1. **Atomic commits**: Each commit should be a single logical change
2. **Conventional commits**: Use clear commit messages
3. **Rebase for clean history**: Use `git pull --rebase` on feature branches
4. **Test before push**: Run `nix flake check` before pushing
5. **Don't commit hardware configs unnecessarily**: Only when hardware changes

## Troubleshooting

### "Already up to date" but changes not showing

The sync service fetches but may not merge. Check:
- `conflictStrategy` - may be blocking
- Working directory status - uncommitted changes
- `autoPull` setting

### Permission denied on pull

If using HTTPS with private repos, ensure:
- `agenix.enable = true` for token injection
- Token file exists at configured path
- Token has appropriate scopes (repo access)

### Large binary files

Avoid committing large files to the repo. Use:
- External storage with fetchers
- Nix store references
- Git LFS if absolutely necessary
