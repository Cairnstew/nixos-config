# Deploy Workflow

> Skill for deploying NixOS configurations via nixos-anywhere, Ventoy USB, and related tools

## Overview

This system uses `nixos-deploy` (a custom wrapper around nixos-anywhere) for remote
deployments and `ventoy-deploy` for multi-boot USB management. All common operations
are available via `just` recipes.

## Quick Reference

```bash
# Activate local configuration
just local

# Activate a remote host
just activate <hostname>

# Deploy to a new machine (nixos-anywhere)
just deploy-run <hostname> [address]

# Deploy with host key injection (first-time setup)
sudo just deploy-with-keys <hostname> [address]

# Deploy desktop with existing partitions (dual-boot, no disko)
sudo just deploy-desktop [address]

# Deploy dry-run / validate disko layout
just deploy-test <hostname>

# Interactive deploy wizard
just deploy-wizard <hostname>
```

## Deployment Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   just deploy-run                        │
│  nixos-deploy deploy run <host> --addr <ip>              │
│  ┌───────────────────────────────────────────────────┐   │
│  │  nixos-anywhere                                   │   │
│  │  1. kexec into NixOS live environment             │   │
│  │  2. partition disk (disko)                        │   │
│  │  3. install NixOS to target                       │   │
│  │  4. reboot                                        │   │
│  └───────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│               just deploy-with-keys                      │
│  nixos-deploy deploy with-keys <host> --addr <ip>        │
│  ┌───────────────────────────────────────────────────┐   │
│  │  Same as above plus:                              │   │
│  │  1. Pre-generate host SSH key                     │   │
│  │  2. Register in agenixManager.keys.systems        │   │
│  │  3. Rekey secrets for new host                    │   │
│  │  4. Deploy with --extra-files (host key)          │   │
│  │  → Secrets work on first boot                     │   │
│  └───────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

## Host Types

### Standard Hosts (laptop, server, wsl)
Use `just deploy-run <host> [addr]` or `just deploy-with-keys <host> [addr]`.

### Desktop (dual-boot with Windows)
- Uses `useExisting` disko mode — does NOT partition the disk
- The NixOS partition must exist before deployment
- Use: `just deploy-desktop [addr]`
- One-time setup from live ISO:
  ```bash
  sudo sgdisk -n 0:0:0 -t 0:8300 -c 0:nixos /dev/sda
  sudo mkfs.ext4 -L nixos /dev/sda4
  ```

## Ventoy Multi-Boot USB

### Build and Deploy
```bash
# Build the deploy ISO (requires --impure for agenix)
sudo just ventoy-iso

# Deploy ISOs + config to Ventoy USB (auto-detect device)
sudo just ventoy-deploy

# Specify device explicitly
sudo just ventoy-deploy /dev/sdb

# Install Ventoy to device (destructive!)
sudo just ventoy-deploy --install /dev/sdb

# Build bundle without deploying
just ventoy-bundle
```

### Verify Deployment
```bash
# Check deploy state
cat /run/media/*/VENTOY/ventoy/.deploy-state

# Verify ISO integrity
sha256sum <store-iso> <usb-iso>

# List deployed ISOs
ls -lah /run/media/*/VENTOY/iso/linux/
```

## Secret Injection Deployment

Some servers need secrets decrypted on first boot. The `deploy-with-keys` flow:

1. **Prepare** (`just prepare <host>`): Generate SSH keypair
2. **Register**: Add host key to `modules/nixos/common.nix` under `agenixManager.keys.systems`
3. **Rekey**: `agenix-manager rekey` to re-encrypt secrets for the new host
4. **Deploy**: `just deploy-with-keys <host> <ip>` — includes `--extra-files` for host key

**If secrets fail on first boot:**
- The host SSH key was freshly generated and doesn't match encryption
- Fix: Add the new host key to `agenixManager.keys.systems`, rekey, rebuild
- Or re-deploy with `just deploy-with-keys`

## Testing Deployments

```bash
# VM-test a host config (validates disko layout, no target machine needed)
just deploy-test <hostname>

# List available hosts
just test-list

# Run full VM test
just test <hostname>
```

## Troubleshooting

### "nixos-anywhere not found"
Deploy script references `inputs.nixos-anywhere` — only available on Linux systems.
Run from the flake root on a Linux host.

### "disko devices not defined"
Desktop uses `useExisting` mode — partition must exist before deployment.
Create partition manually (see above) and use `just deploy-desktop`.

### Ventoy ISO corruption
The deploy script verifies SHA-256 after copy. If verification fails:
1. Delete partial ISO: `rm /run/media/*/VENTOY/iso/linux/nixos-installer*.iso`
2. Re-deploy: `sudo just ventoy-deploy`
3. Verify manually: `sha256sum <store-iso> <usb-iso>`

### Post-deploy: machine unreachable
- Check Tailscale status: the deploy target may not have connected to tailnet yet
- Use direct IP if available (Ethernet/WiFi on same LAN)
- Or physically access the machine to check `tailscale status`
