# Deploy

nixos-anywhere deploy app, VM test runner, and interactive wizard for remote NixOS installation.

## Apps

| App | Command | Description |
|-----|---------|-------------|
| `deploy` | `nix run .#deploy -- <host> [<addr>] [-- flags]` | Deploy NixOS via nixos-anywhere |
| `deploy-with-keys` | `nix run .#deploy-with-keys -- <host> [<addr>]` | Deploy with pre-generated SSH host key + auto-secrets wiring |
| `deploy-test` | `nix run .#deploy-test -- <host>` | VM-test a config (no target machine) |
| `deploy-wizard` | `nix run .#deploy-wizard -- <host>` | Interactive wizard: inspect, partition, deploy |

## `deploy` — Quick Install

Wraps nixos-anywhere with auto-detection:

| Detection | Behavior |
|-----------|----------|
| `disk-config.nix` exists | Full disko mode — partitions created/formatted from the flake's `disko.devices` |
| No `disk-config.nix` | `--phases kexec,install,reboot` — disk must already be partitioned |
| `facter.json` exists | Uses `nixos-facter` backend for hardware config |
| No `facter.json` | Falls back to `nixos-generate-config` |
| `SSHPASS` env var set | Adds `--env-password` for password-based SSH auth |

## `deploy-with-keys` — Deploy with Secrets Wiring

Wraps `deploy` with SSH host key pre-generation and automatic agenix rekeying.
Use this for first-time deployments of hosts that need encrypted secrets on boot.

**Workflow:**

1. Generates an ed25519 keypair in `mktemp -d` (never touches the Nix store or git)
2. Reads the public key and calls `nix run .#secrets-add-host -- <host> <pubkey>` to insert it into `secrets/secrets.nix`
3. Calls `nix run .#secrets-rekey` to re-encrypt all secrets for the new host
4. Runs `nix run .#deploy` with `--extra-files <tmpdir>`, copying the private key to `/etc/ssh/ssh_host_ed25519_key` on the target

**Result:** The target boots with the pre-placed host key. OpenSSH skips key generation,
so agenix finds the matching host key and decrypts all secrets on first boot.

**Idempotency:** If the host already exists in `secrets/secrets.nix`, the command
will error out rather than duplicate. Remove the old entry from the let-block
and systems list before re-deploying.

```
just deploy-with-keys desktop 192.168.1.100
```

All extra arguments after `--` are forwarded directly to nixos-anywhere:

```
nix run .#deploy -- desktop -- --disko-mode mount --phases kexec,install,reboot
```

## `deploy-test` — Validate Before Deploying

Runs nixos-anywhere's `--vm-test` flag, which builds the host's
`system.build.installTest` and runs it inside a QEMU VM. No SSH target needed.

```
nix run .#deploy-test -- desktop
```

This validates:
- The NixOS config evaluates correctly
- The disko partition layout is valid
- The installation process works (in a VM)

Requires `/dev/kvm` access (add user to `kvm` group).

## `deploy-wizard` — Interactive Install

Connects to a live ISO via Tailscale, then:

1. **Disk selection** — enumerates target disks, user picks one
2. **Partition inspection** — shows current layout
3. **NixOS partition setup** — reuses existing, creates in free space, or accepts manual
4. **Dynamic GPT partlabel mapping** — finds ESP/MSR/Windows/NixOS by type GUID or label, renames to match disko expectations (`disk-main-*`)
5. **Password prompt** — optionally sets `seanc` password
6. **Deploys** via `nix run .#deploy -- ... --disko-mode mount`

## just commands

```bash
just deploy desktop              # Deploy via Tailscale
just deploy server 10.0.0.5      # Deploy via raw IP
just deploy-with-keys desktop    # Deploy + pre-generated SSH key + secrets wiring
just deploy-test desktop          # VM test (no target)
just deploy-wizard desktop        # Interactive wizard
just register-host desktop <ip>   # Register host key (post-deploy, for existing hosts)
```

## Files

| File | Purpose |
|------|---------|
| `default.nix` | Import manifest (auto-imported by flake) |
| `deploy.nix` | `apps.deploy` — nixos-anywhere wrapper |
| `deploy-with-keys.nix` | `apps.deploy-with-keys` — deploy + pre-generated host key + secrets wiring |
| `deploy-test.nix` | `apps.deploy-test` — VM test runner |
| `deploy-wizard.nix` | `apps.deploy-wizard` — interactive installer |
| `meta.nix` | Module metadata |
| `tests.nix` | Assertions |
