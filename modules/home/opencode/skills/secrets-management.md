# Secrets Management

> Skill for managing agenix-encrypted secrets in this NixOS configuration

## Overview

Secrets are encrypted with **agenix** (age encryption) and managed via
**agenix-manager** (declarative secret orchestration). The secrets catalog
lives at `modules/nixos/secrets/` (flat, no subdirectories — there is no
top-level `secrets/` dir).

## Architecture

```
modules/nixos/secrets/
├── default.nix              # Module entry: imports agenix + agenix-manager + tests
├── secrets-manifest.json    # SSOT: declares each secret, its scope, owner, group, mode
├── meta.nix                 # Module metadata
├── tests.nix                # L0 assertions + L1/L2 validation services
├── README.md                # Module-level docs
└── <name>.age               # Encrypted blobs (flat, one per secret)
```

Key config lives in `modules/nixos/common.nix`:
```nix
agenixManager = {
  secretsPath = flake.inputs.self + /modules/nixos/secrets;
  keys.groups.systems = [ ... ];   # host SSH keys for boot-time decryption
  keys.groups.users = [ ... ];     # user keys for editing
  keys.groups.main = ...;          # combined
  keys.groups.deployment = [ ... ];# nixos-anywhere deployment age keys
  identities = [ "/etc/ssh/ssh_host_ed25519_key" ];
};
```

## Common Tasks

### Check Status

Get a live snapshot of secret status with the `agenix-manager` tool (`sudo agenix-manager status`).

### Add a New Secret

1. **Declare in manifest**: `modules/nixos/secrets/secrets-manifest.json`
   ```json
   { "name": "my-secret", "scope": "main", "owner": "root" }
   ```
2. **Encrypt**: `agenix-manager new` (TUI, in `nix develop .#secrets`)
   Or manually: `agenix -e modules/nixos/secrets/my-secret.age -r /etc/agenix/secrets.nix`
3. **Add host key** (if new host): `modules/nixos/common.nix` → `agenixManager.keys.groups.systems`
4. **Wire to module** in the consumer's `config.nix`:
   ```
   config.age.secrets.my-secret.path  →  /run/agenix/my-secret
   ```

### Update an Existing Secret

```bash
nix develop .#secrets
agenix-manager edit my-secret
# or manually:
agenix -e modules/nixos/secrets/my-secret.age
```

### Rekey Secrets for a New Host

When adding a new host, its SSH key must be added before secrets work:

1. Add key to `modules/nixos/common.nix`:
   ```nix
   agenixManager.keys.groups.systems = existingKeys ++ [ "ssh-ed25519 AAAA... root@newhost" ];
   ```
2. Rekey all secrets: `agenix-manager rekey`
3. Commit the re-encrypted `.age` files:
   `git add modules/nixos/secrets/*.age`

## Consumption Patterns

### Safe: Check existence first
```nix
my.services.cachix-push.enable = config.age.secrets ? "cache-token";
```
(Note: the current cachix/cache namespace is `my.caches` — see `modules/nixos/caches/`.)

### Unsafe: Direct reference (fails in CI / if secret missing)
```nix
my.services.cachix-push.tokenFile = config.age.secrets.cache-token.path;  # BAD
```

### Conditional enablement
```nix
services.foo = lib.mkIf (config.age.secrets ? "foo-key") {
  environmentFile = config.age.secrets.foo-key.path;
};
```

## Secret Scopes

The manifest's `scope` field selects a key group from `agenixManager.keys.groups.*`:

| Scope | Key group | Purpose |
|-------|-----------|---------|
| `main` | `keys.groups.main` (systems + users) | Default; most secrets |
| `all` | systems + users (all hosts) | Shared secrets (GitHub tokens, API keys) |
| `deployment` | `keys.groups.deployment` | nixos-anywhere deployment keys |

## Key Management

### Key Sources
- **Systems**: SSH host keys (`/etc/ssh/ssh_host_ed25519_key.pub`) — `keys.groups.systems`
- **Users**: User SSH key (`flake.config.me.sshKey`) — `keys.groups.users`
- **Deployment**: Age keys for nixos-anywhere — `keys.groups.deployment`

### Identity Resolution
`agenixManager` reads identities from `/etc/ssh/ssh_host_ed25519_key` during activation.

## Troubleshooting

### "attribute '<name>' missing" during evaluation
The secret doesn't exist on this host. Guard with `config.age.secrets ? "<name>"`.

### Secrets not decrypted on first boot
The host's SSH key was freshly generated and doesn't match encryption.
Solution: `nix run .#prepare-keys-<host>` (pre-generates and registers the host key),
then `just deploy-run <host> <target>` to deploy with `--extra-files`.
Or: add the new host key to `agenixManager.keys.groups.systems`, run
`agenix-manager rekey`, rebuild.

### "age: could not find any applicable identity"
The host doesn't have the private key for any recipient that the secret was encrypted to.
- Check `/etc/ssh/ssh_host_ed25519_key` exists
- Check the corresponding public key is in `agenixManager.keys.groups.systems`
- Rekey with `agenix-manager rekey`

### CI fails on secret references
CI package builds (`modules/flake-parts/packages.nix`) evaluate hosts with
`services.tailscale.enable = lib.mkForce false` and
`services.tailscale-manager.enable = lib.mkForce false` (they do **not** currently
disable agenixManager — secrets evaluate because the `.age` files are committed).
Always guard secret access with `config.age.secrets ? "name"`.
Never depend on `config.age.secrets.<name>.path` existing unconditionally.
