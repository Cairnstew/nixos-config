# Deploy

nixos-anywhere deploy via the system-installed `nixos-deploy` CLI.

All deploy subcommands go through `nixos-deploy deploy <subcommand>`, with paths
auto-wired from the NixOS module config (`my.services.nixos-deploy-tool.settings`).

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

Use this for first-time deployments of hosts that need encrypted secrets on boot.
The SSH key path is configured via the NixOS module (`my.services.nixos-deploy-tool.settings`).

**Workflow:**

1. Ensure the target's public key is in `agenixManager.keys.systems` in `modules/nixos/common.nix`
2. Run `agenix-manager rekey` to re-encrypt all secrets for the new key
3. Deploy with `just deploy-with-keys <host>` (or `nixos-deploy deploy with-keys <host>`)

**Result:** The target boots with the pre-placed host key. OpenSSH skips key generation,
so agenix finds the matching host key and decrypts all secrets on first boot.

```
just deploy-with-keys desktop 192.168.1.100
```

All extra arguments are forwarded directly to nixos-anywhere:

```
nixos-deploy deploy run desktop -- --disko-mode mount --phases kexec,install,reboot
```

## `deploy-test` — Validate Before Deploying

Runs `nixos-anywhere --vm-test` via `nixos-deploy`, which builds the host's
`system.build.installTest` and runs it inside a QEMU VM. No SSH target needed.

```
nixos-deploy deploy test desktop
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
6. **Deploys** via `nixos-deploy deploy run ... --disko-mode mount`

## just commands

```bash
just deploy run desktop          # nixos-deploy deploy run desktop
just deploy with-keys desktop    # nixos-deploy deploy with-keys desktop
just deploy test desktop         # nixos-deploy deploy test desktop
just deploy wizard desktop       # nixos-deploy deploy wizard desktop

# Shorthands with convenient addr defaults:
just deploy-run desktop          # nixos-deploy deploy run desktop --addr nixos@nixos
just deploy-with-keys desktop    # sudo nixos-deploy deploy with-keys desktop --addr nixos@nixos
just deploy-test desktop         # nixos-deploy deploy test desktop
just deploy-wizard desktop       # nixos-deploy deploy wizard desktop
```

## Files

| File | Purpose |
|------|---------|
| `default.nix` | Import manifest (auto-imported by flake) |
| `devshell.nix` | Deploy tool devShell (`nix develop .#deploy-tool`) |
| `meta.nix` | Module metadata |
| `tests.nix` | Assertions |
