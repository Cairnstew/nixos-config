# Secrets — Agenix Reference

## Architecture

Secrets are managed with **agenix-manager** which provides:

- A JSON **manifest** (`secrets-manifest.json`) declaring all secrets, their scopes, and metadata
- Encrypted `.age` files at `modules/nixos/secrets/{name}.age` (flat, no subdirectories)
- A Python CLI (`agenix-manager`) for TUI-based secret management
- Automatic `age.secrets.*` generation from the manifest

## File Layout

```
modules/nixos/secrets/
├── default.nix              ← module entry: imports agenix + agenix-manager + tests
├── tests.nix                ← L0 assertions + L1/L2 validation services
├── meta.nix                 ← module metadata
├── README.md                ← module-level docs
├── secrets-manifest.json    ← SSOT: declares all secrets and their scopes
├── {name}.age               ← encrypted blobs (flat, one per secret)
└── ...
```

## Key Concept

Secrets are **decrypted at activation time**, not at build time. The agenix NixOS module creates a decrypted file at `/run/agenix/<name>` during system activation.

```nix
config.age.secrets."github-token".path  → "/run/agenix/github-token"
```

## Adding a New Secret

### Via agenix-manager TUI (recommended):

```bash
nix develop .#secrets
agenix-manager new
```

The TUI walks you through: entering a name, selecting a scope (key group), opening the editor, and writing the manifest automatically.

### Via plain agenix (manual):

```bash
# 1. Create the encrypted file
agenix -e modules/nixos/secrets/<name>.age -r /etc/agenix/secrets.nix

# 2. Add the entry to the manifest:
#    modules/nixos/secrets/secrets-manifest.json:
#    { "name": "<name>", "scope": "all", "owner": "root" }
```

## Consuming Secrets

### Pattern: Direct reference

```nix
someService.tokenFile = config.age.secrets."github-token".path;
```

### Pattern: Optional secret (safe guard)

```nix
someService.tokenFile = lib.mkIf (config.age.secrets ? "github-token")
  config.age.secrets."github-token".path;
```

**Always use the `?` guard** when the secret might not exist — for example, in CI builds where `agenixManager.enable = false`.

## Encryption Keys

| Key type | Used by | Location |
|----------|---------|----------|
| User ed25519 key | Decrypting secrets on any machine | Defined in `config.nix` (`me.sshKey`) |
| Host SSH host key | Auto-decryption at boot | `/etc/ssh/ssh_host_ed25519_key` |
| macOS agenix key | nix-darwin decryption | `~/.ssh/agenix` (set by `modules/home/core/agenix.nix`) |

All host public keys are listed in `nixos/common.nix` under `agenixManager.keys.systems`. Most secrets use `scope: "all"` so they work on every host.

## Rekeying (Adding a New Host)

```bash
# 1. SSH into the new machine and get its host key:
cat /etc/ssh/ssh_host_ed25519_key.pub

# 2. Add the key to modules/nixos/common.nix:
#    agenixManager.keys.systems = [ ... "ssh-ed25519 ... root@newhost" ];

# 3. Rekey all .age files so the new host can decrypt them:
agenix-manager rekey

# 4. Commit the updated .age blobs:
git add modules/nixos/secrets/*.age
git commit -m "secrets: add new host key"
```

## CLI Commands

| Command | Description |
|---------|-------------|
| `nix develop .#secrets` | Dev shell with agenix + `agenix-manager` + helpers |
| `nix run .#secrets-validate` | Cross-check manifest vs .age files |
| `echo <value> \| nix run .#secrets-set -- <name>` | Re-encrypt a secret from stdin |
| `agenix-manager` (in devShell) | TUI for creating/editing/rekeying secrets |
| `agenix -e modules/nixos/secrets/<name>.age` | Edit a secret via plain agenix |

## CI / Builds Without Secrets

In CI (see `modules/flake-parts/packages.nix`), secrets are disabled:

```nix
nixosCfg.extendModules {
  modules = [ { agenixManager.enable = false; } ];
}
```

This means any module that references `config.age.secrets.*` without a `?` guard
will **fail during CI evaluation**. Always guard secret access.

## Quick Reference

```nix
# Get the decrypted path for a secret
config.age.secrets."github-token".path

# Check if a secret exists
config.age.secrets ? "github-token"

# Disable secrets for a host
{ agenixManager.enable = false; }
```

## See Also

- `modules/nixos/secrets/README.md` — module-level docs
- `modules/nixos/secrets/secrets-manifest.json` — secret manifest (add new secrets here)
- `modules/flake-parts/secrets/main.nix` — CLI tools
- `modules/flake-parts/packages.nix` — secrets disabled for CI
- `GOTCHAS.md` — known footguns
