# Secrets — Agenix Reference

## Architecture

```
secrets/secrets.nix          ← encryption rules (who can decrypt what)
secrets/<path>.age           ← encrypted blobs (committed to git)

modules/nixos/secrets/
├── default.nix              ← imports agenix + sub-modules
├── options.nix              ← my.secrets.enable toggle
├── secrets.nix              ← exposes my.secrets.catalog (read-only)
├── catalog.nix              ← maps logical names → .age files
├── config.nix               ← wires catalog → age.secrets.* when enabled
├── tests.nix                ← assertions + validation
└── README.md                ← module-level docs
```

**Three layers:**
1. **Encryption rules** (`secrets/secrets.nix`) — which SSH keys can decrypt each `.age` file
2. **Catalog** (`modules/nixos/secrets/catalog.nix`) — maps logical paths (e.g. `"github.token"`) to agenix secret names, file paths, and permissions
3. **Consumption** — modules reference `config.age.secrets.<name>.path` at runtime

## Key Insight (nixos-unified)

Secrets are **decrypted at activation time**, not at build time. The agenix NixOS module creates a decrypted file at `/run/agenix/<name>` during system activation. You get the path via:

```nix
config.age.secrets."github-token".path  → "/run/agenix/github-token"
```

This works transparently with `nix run .#activate <host>` — the activation script runs the agenix activation script which decrypts secrets using the host's SSH host key before the system switches over.

## Consuming Secrets

### Pattern 1: Required secret (will fail if missing)

```nix
someService.tokenFile = config.age.secrets."github-token".path;
```

### Pattern 2: Optional secret (safe guard)

```nix
someService.tokenFile = lib.mkIf (config.age.secrets ? "github-token")
  config.age.secrets."github-token".path;
```

**Always use the `?` guard** when the secret might not exist — for example, in CI builds where `my.secrets.enable = false`, or on hosts that don't have a particular secret. Without the guard, activation will fail hard.

### Pattern 3: Conditional enablement

```nix
my.programs.gh.enable = lib.mkDefault (config.age.secrets ? "github-token");
```

### Pattern 4: Resolving a catalog path to a secret name

```nix
config.age.secrets.${config.my.secrets.catalog."tailscale.authKey".name}.path
```

## Encryption Keys

| Key type | Used by | Location |
|----------|---------|----------|
| User ed25519 key | Decrypting secrets on any machine | Defined in `config.nix` (`me.sshKey`) |
| Host SSH host key | Auto-decryption at boot | `/etc/ssh/ssh_host_ed25519_key` |
| macOS agenix key | nix-darwin decryption | `~/.ssh/agenix` (set by `modules/home/core/agenix.nix`) |

The user's SSH public key and all host public keys are listed in `secrets/secrets.nix` under the `all` variable. Most secrets are encrypted to `all` so they work on every host.

## Adding a New Secret

### Step 1: Create the encrypted file

```bash
# From the secrets/ directory:
cd secrets
nix develop               # enters devshell with agenix + 1Password CLI
agenix -e ai/my-key.age   # prompts for value, writes encrypted blob
```

### Step 2: Add to encryption rules

Add the entry to `secrets/secrets.nix`:

```nix
"ai/my-key.age".publicKeys = all;
```

### Step 3: Add to catalog

Add the entry to `modules/nixos/secrets/catalog.nix`:

```nix
"ai.myKey" = secret "my-key" "/secrets/ai/my-key.age" { owner = me.username; };
```

The first argument is the agenix secret name (used as `age.secrets.<name>`).
The logical path (`"ai.myKey"`) is the dotted key used to look it up in `my.secrets.catalog`.

### Step 4: Consume in a module

```nix
{ config, lib, ... }: {
  config = lib.mkIf (config.age.secrets ? "my-key") {
    someOption = config.age.secrets."my-key".path;
  };
}
```

### Step 5: Re-encrypt all secrets

After adding a new host key or changing access rules:

```bash
cd secrets && nix develop
agenix-rekey  # reads private key from 1Password, re-encrypts all .age files
```

## Rekeying (Adding a New Host)

When a new machine is added to the flake:

1. SSH into the new machine and get its host key:
   ```bash
   cat /etc/ssh/ssh_host_ed25519_key.pub
   ```
2. Add the key to `secrets/secrets.nix`:
   ```nix
   mynewhost = "ssh-ed25519 ...";
   ```
3. Re-encrypt all `.age` files so the new host can decrypt them:
   ```bash
   cd secrets && nix develop
   agenix-rekey
   ```
4. Commit the updated `.age` blobs.

## CI / Builds Without Secrets

In CI (see `modules/flake-parts/packages.nix`), secrets are disabled:

```nix
nixosCfg.extendModules {
  modules = [ { my.secrets.enable = false; } ];
}
```

This means any module that references `config.age.secrets.*` without a `?` guard
will **fail during CI evaluation**. Always guard secret access.

## Secret Availability

| Situation | `age.secrets` available? |
|-----------|--------------------------|
| `my.secrets.enable = true` + correct host key | ✅ Yes |
| `my.secrets.enable = true` + wrong host key | ❌ Activation fails |
| `my.secrets.enable = false` (CI) | ❌ No, guarded safely |
| `nix flake check --no-build` | ✅ Evaluates (builds are not triggered) |

## Quick Reference

```nix
# Get the decrypted path for a secret
config.age.secrets."github-token".path

# Check if a secret exists
config.age.secrets ? "github-token"

# Look up a secret's agenix name from the catalog
config.my.secrets.catalog."github.token".name  → "github-token"

# Common patterns
config.my.secrets.catalog."github.token".file  → store path to .age file
config.my.secrets.catalog."github.token".owner → "seanc"
config.my.secrets.catalog."github.token".mode  → "0400"

# Disable secrets for a host
{ my.secrets.enable = false; }
```

## See Also

- `modules/nixos/secrets/README.md` — module-level docs
- `secrets/secrets.nix` — encryption rules
- `modules/nixos/secrets/catalog.nix` — secret catalog (add new secrets here)
- `modules/flake-parts/packages.nix` — secrets disabled for CI
- `modules/nixos/homeManager/config.nix` — example of guarded secret consumption
- `modules/nixos/tailscale/config.nix` — example of required secret consumption
