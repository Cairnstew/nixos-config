# Steam

Unified NixOS module for Steam gaming platform. Replaces the deprecated
`modules/home/steam/` home-manager module.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.programs.steam.enable` | `false` | Enable Steam and related tools |
| `my.programs.steam.remotePlay.openFirewall` | `false` | Open ports for Remote Play Together |
| `my.programs.steam.dedicatedServer.openFirewall` | `false` | Open ports for dedicated servers |
| `my.programs.steam.gamemode.enable` | `false` | Enable Feral Gamemode |
| `my.programs.steam.extraCompatPaths` | `null` | Extra Proton compatibility tool paths |
| `my.programs.steam.extraPackages` | `[]` | Extra Steam-related packages |

## Usage

```nix
my.programs.steam = {
  enable = true;
  remotePlay.openFirewall = true;
  gamemode.enable = true;
  extraCompatPaths = "$HOME/.steam/root/compatibilitytools.d";
};
```

Or via the gaming profile:

```nix
my.profiles.gaming.enable = true;
```

## Notes

- Enables `programs.steam.enable` (NixOS built-in) for 32-bit OpenGL, unfree, and system-wide install.
- Installs `steam-run` and `steamcmd` system-wide.
- `STEAM_EXTRA_COMPAT_TOOLS_PATHS` is set as a home-manager session variable when `extraCompatPaths` is non-null.
- This module replaces the deprecated `modules/home/steam/` home-manager module.
