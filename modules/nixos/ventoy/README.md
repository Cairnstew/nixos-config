# Ventoy

Ventoy USB multi-boot tool — define ISOs and `ventoy.json` configuration at the
flake level (via `modules/flake-parts/ventoy.nix`), then deploy to a USB with a
single command.

## Architecture

```
flake.nix                          ← define ventoy.isos, ventoy.settings
  └─ modules/flake-parts/ventoy.nix  ← declares ventoy.* options
       └─ perSystem                  ← builds ventoy-deploy package with embedded ISOs/config
            └─ packages.ventoy-deploy
                 └─ installed via NixOS module   ← sudo ventoy-deploy
```

## Flake-Level Options (`flake.nix`)

| Option | Description |
|--------|-------------|
| `ventoy.isos` | Attrset of ISO derivations + target paths |
| `ventoy.settings.control` | Ventoy control settings (VTOY_DEFAULT_MENU_MODE, etc.) |
| `ventoy.settings.theme` | Theme configuration (file, display_mode, gfxmode, fonts) |
| `ventoy.settings.menu_class` | Menu class mappings for CSS theming |
| `ventoy.settings.persistence` | Persistence backend mappings |
| `ventoy.settings.injection` | File injection rules |
| `ventoy.settings.auto_install` | Auto-install preseed/kickstart templates |
| `ventoy.settings.conf_replace` | GRUB config replacement snippets |
| `ventoy.extraConfig` | Additional ventoy.json keys |
| `ventoy.device` | Default USB device path |
| `ventoy.mountPoint` | Mount point for data partition (default: `/mnt/ventoy`) |

## Host-Level Options (`my.programs.ventoy`)

| Option | Default | Description |
|--------|---------|-------------|
| `enable` | `false` | Enable Ventoy CLI tools + deploy script |
| `package` | `null` | Ventoy variant (`null` = all, or `ventoy`, `ventoy-full`, etc.) |

## Usage

### 1. Define ISOs and config in `flake.nix`

```nix
{
  inputs = {
    windows-iso-src.url = "github:Cairnstew/uup-dump-build-and-get-windows-iso";
    windows-iso-src.flake = true;
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
    # ...systems, imports (autowired from modules/flake-parts/)...

    ventoy = {
      device = "/dev/sdb";

      settings.control = [
        { VTOY_DEFAULT_MENU_MODE = "0"; }
        { VTOY_DEFAULT_SEARCH_ROOT = "/iso"; }
      ];

      settings.menu_class = [
        { parent = "/iso/windows"; class = "windows"; }
      ];

      isos.win11-23h2 = {
        source = inputs.windows-iso-src.packages.x86_64-linux."windows-iso-22631.7079.23H2.PRO.X64.EN";
        target = "/iso/windows/22631.7079.23H2.PRO.X64.EN.iso";
      };
    };
  };
}
```

### 2. Enable on any host

```nix
{ ... }: {
  my.programs.ventoy.enable = true;
}
```

This installs `ventoy-deploy` + Ventoy CLI tools on that system.

### 3. Deploy

```bash
sudo ventoy-deploy                   # auto-detect USB, auto-mount, deploy
sudo ventoy-deploy -c                # verify Ventoy installation only (no deploy)
sudo ventoy-deploy --check           # same as -c
sudo ventoy-deploy /dev/sdb          # specify device explicitly
sudo ventoy-deploy --device /dev/sdb # same
sudo ventoy-deploy --mount /mnt      # already-mounted partition
```

The script now:
- **Auto-detects** existing mounts first (e.g. udisks2 at `/run/media/$USER/Ventoy`)
- **Verifies** Ventoy is properly installed using `ventoy -l` and label checks
- **Checks disk space** before copying ISOs
- **Size-verifies** each ISO after copy to catch truncation/errors
- **`--check` mode** validates the USB without deploying

### Alternative: build bundle without the NixOS module

```bash
nix build .#ventoy-bundle       # all ISOs + ventoy.json as a derivation
nix run .#ventoy-deploy         # run the deploy script directly
```
