# Secrets

Secrets management CLI tools for the flake. All secrets are encrypted with
[agenix](https://github.com/ryantm/agenix) (age-encrypted `.age` files) and
decrypted at activation time via SSH host keys.

## Apps

| App | Command | Description |
|-----|---------|-------------|
| `secrets-generate` | `nix run .#secrets-generate [--write\|--check]` | Regenerate `secrets/secrets.nix` from the catalog |
| `secrets-edit` | `nix run .#secrets-edit -- <relative-path>` | Create or edit an encrypted `.age` file |
| `secrets-rekey` | `nix run .#secrets-rekey` | Rekey all secrets for all hosts using 1Password |
| `secrets-validate` | `nix run .#secrets-validate` | Validate catalog vs `secrets.nix` vs `.age` files |
| `secrets-new` | `nix run .#secrets-new -- <logical-path> [options]` | Interactive end-to-end secret creation |
| `secrets-set` | `... \| nix run .#secrets-set -- <relative-path>` | Re-encrypt an existing secret with a new value from stdin |
| `secrets-add-host` | `nix run .#secrets-add-host -- <hostname> <ssh-pubkey>` | Add a new SSH host key to `secrets/secrets.nix` |

## Commands in Detail

### `secrets-generate`

Regenerates `secrets/secrets.nix` from `modules/nixos/secrets/catalog.nix`.
The secrets file is auto-generated — hand-edit the catalog, not the output.

| Flag | Description |
|------|-------------|
| (no flags) | Print regenerated file to stdout |
| `--write` | Write directly to `secrets/secrets.nix` |
| `--check` | Exit 1 if the file would change (CI use) |

```bash
# Preview changes
nix run .#secrets-generate

# Write updated secrets.nix
nix run .#secrets-generate -- --write

# CI check
nix run .#secrets-generate -- --check
```

### `secrets-edit`

Decrypts an `.age` file, opens `$EDITOR` (default: nano), and re-encrypts on save.

```bash
# Create or edit a secret
nix run .#secrets-edit -- ai/huggingface-token.age

# Paths are relative to secrets/
nix run .#secrets-edit -- tailscale/tailscale-oauthkey.age
```

### `secrets-rekey`

Decrypts all secrets using the private key from 1Password (stored as
`op://Private/Nixos/private key`), then re-encrypts them for all hosts
listed in `secrets/secrets.nix`. Run this after adding a new host.

Requires 1Password CLI (`op`) to be authenticated.

```bash
nix run .#secrets-rekey
```

### `secrets-validate`

Runs three consistency checks:

1. Every catalog entry with a `fileRel` has a corresponding `.age` file
2. Every `.age` file has a corresponding catalog entry (no orphans)
3. `secrets/secrets.nix` is in sync with the catalog (`secrets-generate --check`)

```bash
nix run .#secrets-validate
```

### `secrets-new`

Interactive workflow to create a new secret end-to-end:

1. Derives the file path from the logical dotted name (e.g. `ai.myNewToken` → `ai/my-new-token.age`)
2. Opens `$EDITOR` to enter the secret value
3. Encrypts the file
4. Prints the catalog entry to add, with instructions

| Flag | Default | Description |
|------|---------|-------------|
| `--owner` | `seanc` | Owner of the decrypted file |
| `--group` | `root` | Group of the decrypted file |
| `--mode` | `0400` | Permissions of the decrypted file |

```bash
nix run .#secrets-new -- ai.myNewToken --owner seanc
```

After creation, add the catalog entry to `modules/nixos/secrets/catalog.nix`
and run `nix run .#secrets-generate -- --write`.

### `secrets-set` (new)

Re-encrypts an existing `.age` file with a new value read from **stdin**.
The file must already exist in the catalog — this is for updating values,
not creating new secrets.

**Security:**
- Secret value is read ONLY from stdin — never from CLI arguments (avoids shell history and `ps` exposure)
- `set +x` prevents bash tracing
- Temp files (`mktemp` + `chmod 600`) are securely deleted on exit via `trap`
- Secret content is zeroed from memory before trap deletes the file

```bash
# Pipe a new value
echo -n "new-token-value" | nix run .#secrets-set -- ai/huggingface-token.age

# From 1Password
op read "op://Private/MySecret/credential" | nix run .#secrets-set -- github/github-token.age

# From a file
cat ./token.txt | nix run .#secrets-set -- tailscale/tailscale-authkey.age
```

**How it works:**
1. Reads stdin into a secure temp file
2. Validates the target `.age` file exists in the catalog
3. Extracts all SSH public keys from `secrets/secrets.nix` via `nix eval --file`
4. Encrypts the temp file with `age -R` using all recipients
5. Overwrites the target `.age` file
6. Clears and deletes temp files

The public key extraction uses the `all` variable from `secrets/secrets.nix`
(union of all user keys and host keys), ensuring the re-encrypted secret is
decryptable by the same set of parties as before.

### `secrets-add-host`

Adds a new SSH host key to the let-block in `secrets/secrets.nix`. The key
is added as a named variable and appended to the `systems` list. After
adding, run `secrets-rekey` to re-encrypt all secrets for the new host.

```bash
# Add a host
nix run .#secrets-add-host -- mynewbox "ssh-ed25519 AAAA... root@mynewbox"

# Verify it was added
grep "mynewbox" secrets/secrets.nix

# Rekey for the new host
nix run .#secrets-rekey
```

## Workflows

### Creating a New Secret

```bash
# 1. Interactive creation (encrypts + prints catalog entry)
nix run .#secrets-new -- ai.myNewToken --owner seanc

# 2. Add the printed catalog stanza to modules/nixos/secrets/catalog.nix

# 3. Regenerate secrets/secrets.nix
nix run .#secrets-generate -- --write

# 4. Validate everything
nix run .#secrets-validate
```

### Updating an Existing Secret

```bash
# Option A: Interactive (opens editor)
nix run .#secrets-edit -- ai/huggingface-token.age

# Option B: From stdin (pipeline-friendly, no editor)
echo -n "new-value" | nix run .#secrets-set -- ai/huggingface-token.age

# Option C: From a secret manager
op read "op://Private/Nixos/token" | nix run .#secrets-set -- ai/huggingface-token.age
```

### Adding a New Host

```bash
# 1. Capture the target's SSH host key
ssh-keyscan -t ed25519 <host-ip> | grep ed25519 | cut -d' ' -f2-3

# 2. Add to secrets/secrets.nix
nix run .#secrets-add-host -- newhost "ssh-ed25519 AAAA... root@newhost"

# 3. Rekey all secrets for the new host
nix run .#secrets-rekey

# 4. Deploy — secrets will decrypt on first boot
```

## Security

- **No plaintext secrets** in the repo. All `.age` files are encrypted.
- **SSH host key based decryption.** Secrets are decrypted at activation time
  using the machine's SSH host key — no shared passphrase.
- **1Password for private key.** The master age private key is stored in
  1Password and never committed.
- **`secrets-set` defense in depth:**
  - Stdin-only value input (no CLI args)
  - `set +x` — no bash tracing
  - `mktemp` + `chmod 600` — secure temp files
  - `trap` — cleanup on any exit path
  - `: > "$TMPFILE"` — zero memory before `rm`

## Files

| File | Purpose |
|------|---------|
| `default.nix` | Import manifest (auto-imported by flake) |
| `main.nix` | All packages, apps, and devShell definitions |
| `meta.nix` | Module metadata for tooling discovery |
| `README.md` | This file |

## DevShell

Enter the development shell for all secrets commands with `nix develop .#secrets`:

```bash
nix develop .#secrets
# Now you can use short names:
secrets-generate --write
secrets-edit ai/huggingface-token.age
secrets-set ai/huggingface-token.age < token.txt
```
