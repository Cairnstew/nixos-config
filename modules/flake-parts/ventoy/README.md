# Ventoy Multi-Boot USB System

This directory implements a complete Ventoy USB management system: ISO building,
Ventoy JSON config generation, unattended Windows answer files, and a deploy
script with hash-based incremental updates and integrity verification.

## Architecture

```
modules/flake-parts/ventoy/
├── README.md              # This file
├── options.nix            # ventoy.* option declarations (ventoy.json schema)
├── answer-files.nix       # Windows unattended XML answer file generation
├── deploy.nix             # Assembles config, ISOs, answer files into a deploy package
├── deploy-script/
│   ├── default.nix        # Nix wrapper — sets env vars, then sources ventoy-deploy.sh
│   ├── ventoy-deploy.sh   # Main deploy logic (device detection, copy, verification)
│   └── tests.nix          # ShellCheck-based tests for the deploy script
├── installer-iso.nix      # Standalone NixOS installer ISO (nixosSystem, not nixos-generators)
└── ts.key                 # Ephemeral Tailscale auth key (one-time-use, tracked in git)
```

### Components

#### 1. Options (`options.nix`)

Declares the entire `ventoy.*` option tree. Supports every Ventoy JSON plugin:
`control`, `theme`, `menu_class`, `persistence`, `injection`, `auto_install`,
`conf_replace`, `menu_alias`, `menu_tip`, `image_list`, `image_blacklist`,
`password`, `dud`, `wimboot`, `vhdboot`, `vtoyboot`, `auto_memdisk`.

Each plugin has mode-suffixed variants (`_legacy`, `_uefi`, `_ia32`, `_aa64`,
`_mips`) for BIOS-mode-specific config.

Also declares:
- `ventoy.isos` — which ISOs to deploy (source store path + target USB path)
- `ventoy.installOptions.*` — `Ventoy2Disk.sh` flags (Secure Boot, GPT, label)
- `ventoy.installerIso.*` — NixOS installer ISO builder options
- `ventoy.answerFileSettings.*` — defaults for Windows answer file generation

#### 2. Answer Files (`answer-files.nix` + `packages/ventoy/answer-files/`)

Generates unattended Windows XML answer files from Nix templates. Each XML
template (`packages/ventoy/answer-files/{dev,minimal,domain,kiosk,dual-boot}.xml`)
contains `@PLACEHOLDER@` variables that get substituted at eval time.

Profiles:
- **dev** — Dev workstation (auto-logon, short timeout)
- **minimal** — Bare Windows install (user creates account)
- **domain** — Corporate domain join
- **kiosk** — Single-app kiosk (999 auto-logons)
- **dual-boot** — Dual-boot setup (wipes disk first)

Generated XML files become Nix store paths exported as
`packages.windows-answ-pro-<profile>`.

#### 3. Deploy Script (`deploy.nix` + `deploy-script/`)

Builds the `ventoy-deploy` package — a shell script wired into `ventoy.json`
config, ISO mappings, answer file mappings, and the installer ISO store path
at eval time.

The script (`ventoy-deploy.sh`) performs:

1. **Device detection** — Auto-find existing Ventoy USB (by `VTOYEFI`/`VENTOY`
   labels), pick removable USB, or accept `--device /dev/sdX`.
2. **Install wizard** — If no Ventoy on the USB, offers to run
   `Ventoy2Disk.sh -i` (formats the drive), with interactive confirmation.
3. **Mount** — Mounts the data partition, detects existing mounts via `findmnt`.
4. **Verify** — Checks `ventoy -l`, finds `VTOYEFI`, estimates disk space.
5. **Deploy installer ISO** — Copies the NixOS live installer ISO to
   `/iso/linux/nixos-installer-x86_64-linux.iso`, with **SHA-256 integrity
   verification** after copy (retries once on failure, aborts on second
   failure).
6. **Deploy ISOs** — Copies each mapped ISO to its target, skips if hash
   unchanged (tracked in `ventoy/.deploy-state`).
7. **Deploy files** — Copies answer files to `/ventoy/scripts/`.
8. **Deploy JSON** — Copies `ventoy.json` and optional `ventoy_grub.cfg`.

#### 4. Installer ISO (`installer-iso.nix`)

Builds a minimal NixOS live installer ISO using a **standalone `nixosSystem`
evaluation** — not your laptop/server config, but a fresh evaluation of
`installation-cd-minimal.nix` with extras:

- `copytoram` kernel param (forces squashfs into RAM at boot, avoids
  Ventoy's loopback race condition)
- `boot.initrd.systemd.enable = lib.mkForce false` (systemd stage 1 does not
  work with ISO boot infrastructure — uses classic bash stage 1)
- `gzip -Xcompression-level 1` squashfs compression
- SSH enabled with `PermitRootLogin = yes` + your SSH keys
- Tailscale with optional auth key (`ts.key`), `--ssh` and `--accept-routes`
- `nix-command` + `flakes` experimental features

The auth key is baked into the ISO at build time via `isoImage.contents` to
`/ts.key`. At boot, the custom `tailscale-autoconnect` service reads it from
the runtime path `/iso/ts.key` (which is where the ISO filesystem exposes it).

## Workflow

### Prerequisites

- A Ventoy-capable USB drive (auto-detected or specified via `--device`)
- `ventoy-full` or `ventoy` package available on the deploy machine
- (Optional) An ephemeral Tailscale auth key for the installer ISO

### Quick Start

```bash
# 1. Generate an ephemeral Tailscale auth key from the admin console
#    and put it in the ts.key file:
echo "tskey-auth-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" > modules/flake-parts/ventoy/ts.key

# 2. Build the installer ISO (optional — ventoy-deploy does this too)
just ventoy-iso

# 3. Deploy everything to a Ventoy USB
just ventoy-deploy

# 4. Or deploy to a specific device
just ventoy-deploy --device /dev/sdb

# 5. Or check the USB without deploying
just ventoy-deploy --check

# 6. Or install Ventoy + deploy to a fresh USB
just ventoy-deploy --install /dev/sdb
```

### Adding ISOs from Host Configs

Hosts can contribute ISOs to the Ventoy deploy by enabling `my.ventoy.enable`:

```nix
# In a host configuration (e.g., configurations/nixos/myhost/default.nix)
{ flake, ... }:
{
  imports = [ flake.inputs.self.nixosModules.common ];

  my.ventoy.enable = true;
  my.ventoy.isos = {
    my-custom-iso = {
      source = pkgs.fetchurl {
        url = "https://example.com/foo.iso";
        hash = "sha256-...";
      };
      target = "/iso/linux/my-custom.iso";
    };
  };
}
```

These ISOs are collected by `ventoy-config.nix` via a foldl over all
`nixosConfigurations` and merged into the deploy.

### Answer File Customization

Override defaults in `ventoy-config.nix`:

```nix
ventoy.answerFileSettings = {
  username = "admin";
  hostname = "MY-PC";
  password = "securepass";
  diskId = "1";  # For Ventoy boot, internal drive is usually 1
};
```

## CLI Reference

| Command | What it does |
|---------|-------------|
| `just ventoy-iso` | `nix build .#ventoy-installer-iso` — builds ISO only |
| `just ventoy-deploy` | `nix run .#ventoy-deploy` — builds all + deploys to USB |
| `just ventoy-deploy --check` | Verify USB only, no write |
| `just ventoy-deploy /dev/sdb` | Deploy to specific device |
| `just ventoy-deploy --install /dev/sdb` | Format + install Ventoy + deploy |
| `just ventoy-deploy --mount /path` | Deploy to already-mounted USB |
| `just ventoy-deploy --device /dev/sdb --mount /path` | Specify both |
| `just ventoy-bundle` | `nix build .#ventoy-bundle` — build file tree only |
| `nix build .#ventoy-deploy` | Build the deploy script (without running) |
| `nix build .#ventoy-installer-iso` | Build the installer ISO |
| `nix build .#ventoy-bundle` | Build the bundle (JSON + ISOs in a tree) |

### Deploy Script CLI

| Flag | Description |
|------|-------------|
| (no args) | Auto-detect USB, mount, deploy |
| `-c, --check` | Verify only, no write |
| `-d, --device DEVICE` | USB block device |
| `-m, --mount PATH` | Already-mounted data partition |
| `--install DEVICE` | Run `Ventoy2Disk.sh -i` then deploy |
| `--force-install DEVICE` | Run `Ventoy2Disk.sh -I` then deploy |
| `--update DEVICE` | Run `Ventoy2Disk.sh -u` then deploy |
| `--info DEVICE` | Show Ventoy info on device |
| `--wizard` | Interactive USB selection + install wizard |
| `-y, --yes` | Auto-confirm prompts |

## Option Reference

### ventoy.settings.* (ventoy.json Plugins)

All standard Ventoy JSON plugins, each with mode-suffixed variants:

```nix
ventoy.settings = {
  control = [ { VTOY_DEFAULT_MENU_MODE = "0"; } ];
  menu_class = [ { parent = "/iso/windows"; class = "windows"; } ];
  menu_alias = [
    { image = "/iso/windows/win11.iso"; alias = "Windows 11"; }
    { dir = "/iso/linux"; alias = "[ Linux ISOs ]"; }
  ];
  auto_install = [
    {
      image = "/iso/windows/win11.iso";
      template = [ "/ventoy/scripts/dev.xml" ];
    }
  ];
  theme = {
    file = "/ventoy/theme/blur/theme.txt";
    gfxmode = "1920x1080";
  };
  # Mode-specific (applies only in UEFI mode)
  control_uefi = [ { VTOY_DEFAULT_MENU_MODE = "1"; } ];
};
```

### ventoy.installerIso.*

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Build and deploy a NixOS live installer ISO |
| `sshKeys` | list of str | `[]` | SSH public keys for root |
| `extraPackages` | list of pkg | `[]` | Extra packages in the ISO |
| `system` | str | `"x86_64-linux"` | System architecture |
| `tailscale.enable` | bool | `false` | Enable Tailscale on boot |
| `tailscale.authKeyFile` | null or path | `null` | Path to auth key file (in flake source) |

### ventoy.installOptions.*

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `secureBoot` | bool | `false` | `-s` flag for Ventoy2Disk.sh |
| `gpt` | bool | `false` | `-g` flag for GPT partition table |
| `label` | str | `"Ventoy"` | `-L` flag for data partition label |
| `reserveSizeMb` | null or int | `null` | `-r` flag for reserved space |

## Debugging

### ISO Fails to Boot

Common symptoms and fixes:

1. **`failed to mount /sysroot/nix/.ro-store`**
   - **Possible cause 1:** `boot.initrd.systemd.enable = true` (default in
     recent nixos-unstable). The ISO boot infrastructure does not support
     systemd stage 1 (nixpkgs#217173).
   - **Fix:** Ensure `boot.initrd.systemd.enable = lib.mkForce false;` is set
     in the ISO config.
   - **Possible cause 2:** High squashfs compression level causing decompression
     failure over Ventoy's loopback. Try `gzip -Xcompression-level 1` or
     `zstd -Xcompression-level 3`.
   - **Fix:** Lower compression level or switch to gzip.

2. **`fsconfig() failed: unable to read id index table`**
   - **Cause:** The squashfs image is truncated — the id index table lives at
     the end of the file.
   - **Most likely:** The deploy script's `cp` silently corrupted the file on
     exfat (see GOTCHAS.md).
   - **Fix:** Delete the ISO on the USB and redeploy. Verify SHA-256 after
     copy: `sha256sum <store-iso> <usb-iso>`. If mismatch persists, the exfat
     driver or USB hardware is unreliable — use `rsync --checksum` or `dd`.

3. **ISO not found in Ventoy menu**
   - **Cause:** The ISO was deployed to a path that doesn't match Ventoy's
     search root (`VTOY_DEFAULT_SEARCH_ROOT` which defaults to `/iso`).
   - **Fix:** Check `ventoy.json` has `VTOY_DEFAULT_SEARCH_ROOT` set to `/iso`.
     The ISO path is `/iso/linux/nixos-installer-x86_64-linux.iso`.

### Deploy Script Issues

1. **`auto-detection misses USB`**
   - **Cause:** The script checks for `VTOYEFI`/`VENTOY` labels via `lsblk`.
     Some USB drives have different labels.
   - **Fix:** Use `--device /dev/sdX` explicitly.

2. **`deploy succeeds but ISOs don't change`**
   - **Cause:** The hash-based skip logic (`ventoy/.deploy-state`) thinks files
     are up to date even though the store path changed.
   - **Fix:** Delete the state file and redeploy:
     ```bash
     rm /run/media/*/VENTOY/ventoy/.deploy-state
     just ventoy-deploy
     ```

3. **`cp to exfat corrupts large files`**
   - **Cause:** The installer ISO copy step lacked checksum verification,
     allowing silent corruption of 1.5GB files on exfat.
   - **Fix:** This has been fixed — the deploy script now verifies SHA-256
     after every installer ISO copy, with an automatic retry on failure. If
     you still see corruption, try `rsync --checksum` or a different USB drive.

### Deploying Without the Nix Wrapper

The `ventoy-deploy` binary reads all configuration from environment variables
set by `deploy-script/default.nix`. To run it outside the Nix wrapper:

```bash
export VENTOY_JSON=/path/to/ventoy.json
export ISO_MAPPINGS=("src|target|hash")
export FILE_MAPPINGS=("src|target|hash")
export BUILD_INSTALLER_ISO=1
export INSTALLER_ISO=/nix/store/...-nixos-minimal-...iso
export DEFAULT_DEVICE=""
export MOUNT_POINT="/mnt/ventoy"
# Then source the script and call main
. modules/flake-parts/ventoy/deploy-script/ventoy-deploy.sh
main "$@"
```

## Packaging Detail

### Not in `packages/`

The `ventoy-deploy` and `ventoy-installer-iso` packages are **not** in
`packages/` because they require custom arguments (`ventoyJson`, `isoMappings`,
etc.) that `pkgs.callPackage` can't provide. They're built in
`deploy.nix`'s `perSystem` block via `pkgs.callPackage ./deploy-script` with
all args wired from the `ventoy.*` options.

### ventoy-bundle

The `ventoy-bundle` package (`nix build .#ventoy-bundle`) produces a directory
tree containing `ventoy.json`, `ventoy_grub.cfg`, and all ISOs as symlinks.
Useful for manual deployment or inspection.
