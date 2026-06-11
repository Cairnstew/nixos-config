# Secrets Management

> Skill for managing agenix-encrypted secrets in this NixOS configuration

## Overview

Secrets are encrypted with **agenix** (age encryption) and managed via
**agenix-manager** (declarative secret orchestration). The secrets catalog
lives at `modules/nixos/secrets/`.

## Architecture

```
secrets/
├── secrets.nix              # Key definitions: which keys can decrypt what
├── <category>/<name>.age    # Encrypted blobs
├── flake.nix                # Standalone secrets flake

modules/nixos/secrets/
├── default.nix              # Module entry point
├── secrets-manifest.json    # Declarative SSOT: name, scope, owner for each secret
├── meta.nix                 # Module metadata
├── tests.nix                # L1/L2 validation
├── <name>.age               # Encrypted blobs (flat, one per secret)
```

## Common Tasks

### Add a New Secret

1. **Declare in manifest**: `modules/nixos/secrets/secrets-manifest.json`
   ```json
   { "name": "my-secret", "scope": "all", "owner": "root" }
   ```
2. **Encrypt**: `agenix-manager new my-secret`
   Or manually: `agenix -e modules/nixos/secrets/my-secret.age`
3. **Add host key** (if new host): `modules/nixos/common.nix` → `agenixManager.keys.systems`
4. **Wire to module** in the consumer's `config.nix`:
   ```
   config.age.secrets.my-secret.path  →  /run/agenix/my-secret
   ```

### Update an Existing Secret

```bash
agenix-manager edit my-secret
# or manually:
agenix -e modules/nixos/secrets/my-secret.age
```

### Rekey Secrets for a New Host

When adding a new host, its SSH key must be added before secrets work:

1. Add key to `modules/nixos/common.nix`:
   ```nix
   agenixManager.keys.systems = existingKeys ++ [ "ssh-ed25519 AAAA... root@newhost" ];
   ```
2. Rekey all secrets: `agenix-manager rekey`
3. Commit the re-encrypted `.age` files

## Consumption Patterns

### Safe: Check existence first
```nix
my.services.cachix-push.enable = config.age.secrets ? "cache-token";
```

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

| Scope | Location | Purpose |
|-------|----------|---------|
| `all` | All hosts | Shared secrets (GitHub tokens, API keys) |
| `host-<name>` | Specific host | Host-specific secrets (WireGuard keys, etc.) |
| `user-<name>` | Specific user | User-specific secrets |

## Key Management

### Key Sources
- **Systems**: SSH host keys (`/etc/ssh/ssh_host_ed25519_key.pub`)
- **Users**: User SSH keys (`~/.ssh/id_ed25519.pub`)
- **Deployment**: Age keys for nixos-anywhere

### Identity Resolution
`agenixManager` reads identities from `/etc/ssh/ssh_host_ed25519_key` during activation.
Key groups defined in `modules/nixos/common.nix`:
```nix
agenixManager = {
  keys.groups.systems = [ ... ];   # Host keys for decryption
  keys.groups.users = [ ... ];     # User keys for editing
  keys.groups.main = ...;          # Combined (both)
};
```

## Troubleshooting

### "attribute '<name>' missing" during evaluation
The secret doesn't exist on this host. Guard with `config.age.secrets ? "<name>"`.

### Secrets not decrypted on first boot
The host's SSH key was freshly generated and doesn't match encryption.
Solution: Use `just deploy-with-keys <host>` which pre-generates and registers the key.
Or: Add the new host key manually, run `agenix-manager rekey`, rebuild.

### "age: could not find any applicable identity"
The host doesn't have the private key for any recipient that the secret was encrypted to.
- Check `/etc/ssh/ssh_host_ed25519_key` exists
- Check the corresponding public key is in `agenixManager.keys.systems`
- Rekey with `agenix-manager rekey`

### CI fails on secret references
CI (`modules/flake-parts/packages.nix`) sets `agenixManager.enable = false`.
Always guard secret access with `config.age.secrets ? "name"`.
Never depend on `config.age.secrets.<name>.path` existing unconditionally.
