# Secrets — CLI Tools

Secrets management CLI tools for the flake. All secrets are encrypted with
[agenix](https://github.com/ryantm/agenix) (age-encrypted `.age` files) and
decrypted at activation time via SSH host keys. Secret management is delegated
to [agenix-manager](https://github.com/Cairnstew/agenix-manager).

## Apps

| App | Command | Description |
|-----|---------|-------------|
| `secrets-validate` | `nix run .#secrets-validate` | Validate manifest vs `.age` files |
| `secrets-set` | `... \| nix run .#secrets-set -- <name>` | Re-encrypt an existing secret with a new value from stdin |

## Commands in Detail

### `secrets-validate`

Runs two consistency checks:

1. Every manifest entry has a corresponding `.age` file in `modules/nixos/secrets/`
2. Every `.age` file has a corresponding manifest entry (flags orphans)

```bash
nix run .#secrets-validate
```

### `secrets-set`

Re-encrypts an existing `.age` file with a new value read from **stdin**.
The secret must have a manifest entry and `.age` file.

**Security:**
- Secret value is read ONLY from stdin — never from CLI args
- Temp files are securely deleted on exit

```bash
# Pipe a new value
echo -n "new-token-value" | nix run .#secrets-set -- huggingface-token

# From 1Password
op read "op://Private/MySecret/credential" | nix run .#secrets-set -- github-token
```

**How it works:**
1. Reads stdin into a secure temp file
2. Validates the target secret exists in the manifest
3. Extracts public keys from agenix-manager cache at `/etc/agenix/keys-snapshot.json`
4. Encrypts the temp file with `age -R` using all recipients
5. Overwrites the target `.age` file

## Primary Tooling: `agenix-manager`

The [agenix-manager](https://github.com/Cairnstew/agenix-manager) Python CLI
provides a TUI for all secret operations:

```bash
# Enter the dev shell (includes agenix-manager)
nix develop .#secrets

# TUI status screen
agenix-manager

# Common operations within the TUI:
#   n  — create a new secret
#   e  — edit an existing secret
#   r  — rekey all secrets
#   d  — decrypt a secret to stdout
#   R  — remove a secret
```

## Editing via plain agenix

```bash
agenix -e modules/nixos/secrets/<name>.age -r /etc/agenix/secrets.nix
```

## DevShell

```bash
nix develop .#secrets
# Now you can use short names:
agenix-manager
secrets-validate
```

## Files

| File | Purpose |
|------|---------|
| `default.nix` | Import manifest (auto-imported by flake) |
| `main.nix` | Package, app, and devShell definitions |
| `meta.nix` | Module metadata for tooling discovery |
| `README.md` | This file |
