# Deploy Module

NixOS deploy ISO configuration with embedded Tailscale auto-auth.

The deploy ISO is a minimal NixOS live image that connects to your tailnet at boot,
enabling remote SSH access for headless installation. Tailscale is authenticated
via a pre-auth key stored as an encrypted `.age` file and decrypted at boot using
a co-located age private key.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `my.deploy.enable` | `bool` | `true` | Enable deploy ISO configuration |

The deploy module sets `my.live.isos.deploy` with sensible defaults. Override any
option via `my.live.isos.deploy.<option>` in your host config.

## How It Works

1. **`tailscale-live-key.age`** — encrypted Tailscale pre-auth key, lives at
   `modules/nixos/secrets/tailscale-live-key.age` (referenced via `self + /path`)
2. **`live-iso-ssh-key`** — plaintext age private key co-located in this module
   (`modules/nixos/deploy/live-iso-ssh-key`). Decrypts the tailscale key at boot.
3. At ISO boot, a systemd service runs `age -d -i live-iso-ssh-key -o authkey tailscale-live-key.age`,
   then `tailscale up --authkey $(cat authkey)`.

### Security Note

The live-iso-ssh-key private key is embedded plaintext in the Nix store and ISO.
This is acceptable because:

- It's a throwaway keypair — it only decrypts the single short-lived tailscale
  pre-auth key (`tailscale-live-key`)
- The tailscale pre-auth key should be single-use with a short expiry configured
  in the Tailscale admin console
- Anyone with the ISO can extract the age key, but the tailscale key it unlocks
  should already be expired or consumed by then

**Rotate both secrets after each deploy ISO build cycle.**

## Key Rotation

The `live-iso-ssh-key` age keypair serves two purposes:

1. **Plaintext** in this module (`modules/nixos/deploy/live-iso-ssh-key`) for ISO embedding
2. **Encrypted** in the secrets directory (`modules/nixos/secrets/live-iso-ssh-key.age`)
   for use on running systems (e.g., during rekeying)

When rotating, both copies must be updated together:

```bash
# 1. Generate a new age keypair
age-keygen -o /tmp/live-iso-ssh-key

# 2. Extract the public key
age-keygen -y /tmp/live-iso-ssh-key > /tmp/live-iso-ssh-key.pub

# 3. Get a fresh tailscale pre-auth key (short expiry, single-use)
#    from https://login.tailscale.com/admin/settings/authkeys

# 4. Re-encrypt the tailscale auth key with the new public key
echo -n "<new-ts-authkey>" | age -R /tmp/live-iso-ssh-key.pub -o modules/nixos/secrets/tailscale-live-key.age

# 5. Update the plaintext key in the deploy module
cp /tmp/live-iso-ssh-key modules/nixos/deploy/live-iso-ssh-key

# 6. Re-encrypt the private key for host systems
agenix -e modules/nixos/secrets/live-iso-ssh-key.age < /tmp/live-iso-ssh-key

# 7. Clean up
rm -f /tmp/live-iso-ssh-key /tmp/live-iso-ssh-key.pub

# 8. Commit the updated .age file and plaintext key
git add modules/nixos/secrets/tailscale-live-key.age
git add modules/nixos/secrets/live-iso-ssh-key.age
git add modules/nixos/deploy/live-iso-ssh-key
git commit -m "deploy: rotate live ISO keys"
```

**Rotation cadence:** After each deploy ISO build cycle. The tailscale pre-auth key
should be single-use with a short expiry (e.g., 1 hour), so a new key is needed for
every ISO.

## Files

| File | Purpose |
|------|---------|
| `default.nix` | Module entry: declares `my.deploy.enable`, wires `my.live.isos.deploy` |
| `meta.nix` | Module metadata |
| `tests.nix` | L0 assertion + validation service |
| `live-iso-ssh-key` | Plaintext age private key for decrypting tailscale auth at boot |
| `README.md` | This file |
