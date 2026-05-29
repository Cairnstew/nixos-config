# Ventoy

Ventoy USB multi-boot tool — define ISOs and `ventoy.json` configuration at the
flake level (via `modules/flake-parts/ventoy.nix`), then deploy to a USB with a
single command. ISOs can be declared per-host using `my.ventoy.isos`.

## Architecture

```
modules/flake-parts/ventoy.nix        ← declares ventoy.* options, generates ventoy-deploy
modules/flake-parts/ventoy-config.nix ← common config + per-host ISO aggregation
                                            │
                    ┌───────────────────────┴───────────────────────┐
                    ↓                                               ↓
configurations/nixos/desktop/default.nix        configurations/nixos/server/default.nix
  my.ventoy.isos.win11-23h2 = ...               my.ventoy.isos.<name> = ...
                    │                                               │
                    └───────────────────────┬───────────────────────┘
                                            ↓
                                  ventoy-deploy ← deploys ALL
                                    ISOs from every host
```

### Key Concepts

| Layer | File | What it does |
|-------|------|-------------|
| **Flake-part module** | `modules/flake-parts/ventoy.nix` | Defines `ventoy.*` options, generates `ventoy-deploy` + answer file packages |
| **Config** | `modules/flake-parts/ventoy-config.nix` | Sets common config (control, menu_class, GParted ISO, answer files). Aggregates per-host ISOs from `config.flake.nixosConfigurations` |
| **NixOS host module** | `modules/nixos/ventoy/` | Host-level options: `my.programs.ventoy.enable` (install tools), `my.ventoy.enable` + `my.ventoy.isos` (contribute ISOs) |

## Flake-Level Options (`ventoy.*`)

### ISO Configuration

| Option | Description |
|--------|-------------|
| `ventoy.isos` | Attrset of ISO derivations + target paths (merged from common + per-host) |
| `ventoy.device` | Default USB device path (empty = auto-detect) |
| `ventoy.mountPoint` | Mount point for data partition (default: `/mnt/ventoy`) |
| `ventoy.grubConfig` | Custom `ventoy_grub.cfg` for F6 menu extension |
| `ventoy.extraConfig` | Arbitrary ventoy.json keys (for non-typed overrides) |

### Plugin Settings (`ventoy.settings.*`)

| Plugin | Type | Description |
|--------|------|-------------|
| `control` | `list of attrs` | Global control settings (VTOY_DEFAULT_MENU_MODE, etc.) |
| `theme` | `null or submodule` | Theme configuration |
| `menu_class` | `list of submodule` | Menu class mappings for CSS theming |
| `menu_alias` | `list of submodule` | Friendly names for ISOs/directories |
| `menu_tip` | `null or submodule` | Tooltip messages when ISO is selected |
| `persistence` | `list of submodule` | Persistence backend mappings |
| `injection` | `list of submodule` | File injection rules |
| `auto_install` | `list of submodule` | Auto-install preseed/kickstart templates |
| `conf_replace` | `list of submodule` | GRUB config replacement snippets |
| `image_list` | `list of string` | ISO whitelist (replaces auto-scan) |
| `image_blacklist` | `list of string` | ISO blacklist (hides from menu) |
| `password` | `attrs` | Password protection (stored in /nix/store — use with care) |
| `dud` | `list of submodule` | Driver Update Disk mappings (RHEL/CentOS/SUSE) |
| `wimboot` | `list of submodule` | Wimboot configuration |
| `vhdboot` | `list of submodule` | Windows VHD/VHDX boot configuration |
| `vtoyboot` | `list of submodule` | Linux vDisk boot configuration |
| `auto_memdisk` | `list of string` | Image paths for auto Memdisk mode |

Each plugin also supports **per-BIOS-mode variants** via suffix:
`_uefi`, `_legacy`, `_ia32`, `_aa64`, `_mips`.

Example: `control_uefi`, `theme_legacy`, `menu_alias_uefi`

### Install Options (`ventoy.installOptions`)

| Option | Default | Description |
|--------|---------|-------------|
| `secureBoot` | `false` | `-s` flag when installing |
| `gpt` | `false` | `-g` flag (GPT instead of MBR) |
| `label` | `"Ventoy"` | `-L` flag (data partition label) |
| `reserveSizeMb` | `null` | `-r SIZE_MB` flag |

### Theme Submodule Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `file` | `string or list of string` | *(required)* | Theme.txt path, or array for multi-theme |
| `default_file` | `null or int` | `null` | 0=random, 1+=index (multi-theme only) |
| `resolution_fit` | `null or 0/1` | `null` | Auto-select theme by screen resolution |
| `gfxmode` | `string` | `"1024x768"` | GRUB resolution |
| `display_mode` | `string` | `"GUI"` | GUI, CLI, serial, or serial_console |
| `serial_param` | `null or string` | `null` | Serial port params |
| `ventoy_left` | `null or string` | `null` | Version info left position |
| `ventoy_top` | `null or string` | `null` | Version info top position |
| `ventoy_color` | `null or string` | `null` | Version info color |
| `fonts` | `list of string` | `[]` | Font .pf2 paths |

## Host-Level Options

### Install tools (`my.programs.ventoy.*`)

| Option | Default | Description |
|--------|---------|-------------|
| `enable` | `false` | Enable Ventoy CLI tools + deploy script on this host |
| `package` | `null` | Ventoy variant (`null` = all, or `ventoy`, `ventoy-full`, etc.) |

### Contribute ISOs (`my.ventoy.*`)

| Option | Default | Description |
|--------|---------|-------------|
| `enable` | `false` | This host contributes ISOs/config to the Ventoy USB |
| `isos` | `{}` | Attrset of ISO entries (`source` + `target`) that this host contributes |

## Usage

### 1. A host declares its ISOs

In the host config (e.g. `configurations/nixos/desktop/default.nix`):

```nix
{ flake, ... }: {
  my.programs.ventoy.enable = true;   # install tools
  my.ventoy.enable = true;            # contribute ISOs to the ventoy USB

  my.ventoy.isos = {
    win11-23h2 = {
      source = flake.inputs.windows-iso-src.packages.x86_64-linux."windows-iso-22631.7079.23H2.PRO.X64.EN";
      target = "/iso/windows/22631.7079.23H2.PRO.X64.EN.iso";
    };
  };
}
```

### 2. Common config + aggregation in `modules/flake-parts/ventoy-config.nix`

Common ISOs (GParted), global settings (menu_class, control), and answer files
are defined here. Per-host ISOs from all hosts are automatically merged.

### 3. Deploy

```bash
sudo ventoy-deploy                         # auto-detect, mount, deploy ALL host ISOs
sudo ventoy-deploy --check                 # verify USB only
sudo ventoy-deploy /dev/sdb                # explicit device
sudo ventoy-deploy --mount /mnt/ventoy     # already-mounted partition

sudo ventoy-deploy --install /dev/sdb      # install Ventoy to USB
sudo ventoy-deploy --update /dev/sdb       # update Ventoy on USB
sudo ventoy-deploy --info /dev/sdb         # show Ventoy version info
```

The script:
- **Auto-detects** Ventoy USB via label + `ventoy -l` verification
- **Finds existing mounts** first (e.g. udisks2 at `/run/media/$USER/Ventoy`)
- **Verifies** Ventoy installation before deploying
- **Checks disk space** before copying ISOs
- **Size-verifies** each ISO after copy to catch truncation
- Deploys `ventoy.json` to `<partition>/ventoy/ventoy.json`
- Deploys `ventoy_grub.cfg` if `ventoy.grubConfig` is set

### Alternative: build bundle without the NixOS module

```bash
nix build .#ventoy-bundle       # all ISOs + ventoy.json + grub.cfg as derivation
nix run .#ventoy-deploy         # run deploy script directly
```
