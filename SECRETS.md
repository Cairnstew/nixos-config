# Secrets — Agenix Reference

## Architecture

```
secrets/secrets.nix          ← AUTO-GENERATED from catalog (run `secrets-generate --write`)
secrets/<path>.age           ← encrypted blobs (committed to git)

modules/nixos/secrets/
├── default.nix              ← imports agenix + sub-modules
├── options.nix              ← my.secrets.enable toggle
├── catalog.nix              ← SINGLE SOURCE OF TRUTH: maps logical paths → .age files
├── config.nix               ← wires catalog → age.secrets.* when enabled
├── tests.nix                ← assertions + validation
└── README.md                ← module-level docs
```

**Three layers:**
1. **Catalog** (`modules/nixos/secrets/catalog.nix`) — single source of truth. Maps logical paths (e.g. `"github.token"`) to `.age` file paths.
2. **Encryption rules** (`secrets/secrets.nix`) — AUTO-GENERATED from catalog by `secrets-generate`. Which SSH keys can decrypt each `.age` file.
3. **Consumption** — Modules reference `config.age.secrets.<name>.path` at runtime; **should use the catalog** for lookups.

## Key Insight (nixos-unified)

Secrets are **decrypted at activation time**, not at build time. The agenix NixOS module creates a decrypted file at `/run/agenix/<name>` during system activation. You get the path via:

```nix
config.age.secrets."github-token".path  → "/run/agenix/github-token"
```

This works transparently with `nix run .#activate <host>`.

## Adding a New Secret

### One-command workflow (recommended):

```bash
nix run .#secrets-new -- ai.myNewToken --owner seanc
```

This will:
1. Create the encrypted file at `secrets/ai/my-new-token.age` (opens $EDITOR)
2. Print the catalog entry to add to `modules/nixos/secrets/catalog.nix`
3. After adding the entry, run `secrets-generate --write`

### Manual workflow:

```bash
# 1. Create the encrypted file
nix run .#secrets-edit -- ai/my-new-token.age

# 2. Add to catalog (modules/nixos/secrets/catalog.nix):
# "ai.myNewToken" = secret "/secrets/ai/my-new-token.age" { owner = me.username; };

# 3. Regenerate encryption rules (from repo root):
nix develop .#secrets -c secrets-generate
#   or: nix run .#secrets-generate -- --write
```

The secret name is derived automatically from the filename stem (e.g., `my-new-token.age` → `"my-new-token"`).

## Consuming Secrets

### Pattern 1: Using the catalog (preferred)

```nix
let
  sec = config.my.secrets;
  hasSecret = path: sec.enable && (sec.catalog ? ${path})
    && (config.age.secrets ? sec.catalog.${path}.name);
  secretName = path: sec.catalog.${path}.name or null;
in
config = lib.mkIf (hasSecret "github.token") {
  someService.tokenFile = config.age.secrets.${secretName "github.token"}.path;
};
```

### Pattern 2: Direct reference (simple cases)

```nix
someService.tokenFile = config.age.secrets."github-token".path;
```

### Pattern 3: Optional secret (safe guard)

```nix
someService.tokenFile = lib.mkIf (config.age.secrets ? "github-token")
  config.age.secrets."github-token".path;
```

**Always use the `?` guard** when the secret might not exist — for example, in CI builds where `my.secrets.enable = false`.

## Encryption Keys

| Key type | Used by | Location |
|----------|---------|----------|
| User ed25519 key | Decrypting secrets on any machine | Defined in `config.nix` (`me.sshKey`) |
| Host SSH host key | Auto-decryption at boot | `/etc/ssh/ssh_host_ed25519_key` |
| macOS agenix key | nix-darwin decryption | `~/.ssh/agenix` (set by `modules/home/core/agenix.nix`) |

The user's SSH public key and all host public keys are listed in `secrets/secrets.nix` under the `all` variable. Most secrets are encrypted to `all` so they work on every host.

## Rekeying (Adding a New Host)

```bash
# 1. SSH into the new machine and get its host key:
cat /etc/ssh/ssh_host_ed25519_key.pub

# 2. Add the key to secrets/secrets.nix (the let-block is hand-maintained):
#    mynewhost = "ssh-ed25519 ...";
#    systems = [ laptop server wsl desktop mynewhost ];

# 3. Re-encrypt all .age files so the new host can decrypt them:
nix run .#secrets-rekey

# 4. Commit the updated .age blobs:
git add secrets/*.age secrets/**/*.age
git commit -m "secrets: add new host key"
```

## CLI Commands

All available from the repo root:

| Command | Description |
|---------|-------------|
| `nix develop .#secrets` | Dev shell with agenix + 1Password + helper commands |
| `nix run .#secrets-edit -- <path>` | Create/edit an encrypted `.age` file |
| `nix run .#secrets-generate [--write]` | Regenerate `secrets/secrets.nix` from catalog |
| `nix run .#secrets-rekey` | Re-encrypt all secrets using 1Password |
| `nix run .#secrets-validate` | Cross-check catalog, secrets.nix, and .age files |
| `nix run .#secrets-new -- <logical-path>` | Interactive secret creation workflow |

## CI / Builds Without Secrets

In CI (see `modules/flake-parts/packages.nix`), secrets are disabled:

```nix
nixosCfg.extendModules {
  modules = [ { my.secrets.enable = false; } ];
}
```

This means any module that references `config.age.secrets.*` without a `?` guard
will **fail during CI evaluation**. Always guard secret access.

## Catalog Structure

The catalog at `modules/nixos/secrets/catalog.nix` is the single source of truth.
Each entry maps a logical path to a `.age` file:

```nix
"github.token" = secret "/secrets/github/github-token.age" { owner = me.username; group = "users"; };
```

The agenix name is **derived automatically** from the filename stem:
- `github-token.age` → `"github-token"`
- `tailscale/tailscale-authkey.age` → `"tailscale-authkey"`

The agenix file path (used in `secrets/secrets.nix`) is also derived from the
fileRel by stripping the `/secrets/` prefix.

## Quick Reference

```nix
# Get the decrypted path for a secret
config.age.secrets."github-token".path

# Check if a secret exists
config.age.secrets ? "github-token"

# Look up a secret's agenix name from the catalog
config.my.secrets.catalog."github.token".name  → "github-token"

# Check if catalog entry exists
config.my.secrets.catalog ? "github.token"

# Common patterns
config.my.secrets.catalog."github.token".file  → store path to .age file
config.my.secrets.catalog."github.token".owner → "seanc"
config.my.secrets.catalog."github.token".mode  → "0400"

# Disable secrets for a host
{ my.secrets.enable = false; }
```

## See Also

- `modules/nixos/secrets/README.md` — module-level docs
- `modules/nixos/secrets/catalog.nix` — secret catalog (add new secrets here)
- `modules/flake-parts/secrets.nix` — CLI tools (devShell, secrets-generate, etc.)
- `secrets/secrets.nix` — encryption rules (AUTO-GENERATED, do not edit attrset)
- `modules/flake-parts/packages.nix` — secrets disabled for CI
- `GOTCHAS.md` — known footguns
