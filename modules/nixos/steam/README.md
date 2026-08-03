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
| `my.programs.steam.shaderPreCaching.enable` | `false` | Ensure Steam shader pre-caching is on in config.vdf |
| `my.programs.steam.shaderPreCaching.backgroundThreads` | `null` | CPU threads for Vulkan shader background processing (auto-detected when `null`) |
| `my.programs.steam.extraCompatPaths` | `null` | Extra Proton compatibility tool paths |
| `my.programs.steam.extraPackages` | `[]` | Extra Steam-related packages |
| `my.programs.steam.hyprland.enable` | `false` | Hyprland window rules forcing Steam games onto a monitor |
| `my.programs.steam.hyprland.forceMonitor` | `null` | Fallback monitor for `steam_app_.*` windows (per-game overrides) |
| `my.programs.steam.games.<name>.appId` | — | Steam App ID |
| `my.programs.steam.games.<name>.name` | `""` | Human-readable name in the app menu |
| `my.programs.steam.games.<name>.env` | `{}` | Environment variables set at launch (e.g. `PROTON_USE_WINED3D`) |
| `my.programs.steam.games.<name>.monitor` | `null` | Hyprland monitor to force the game onto |
| `my.programs.steam.games.<name>.windowClass` | `null` | Hyprland window class (defaults to `steam_app_<appId>`) |
| `my.programs.steam.games.<name>.gamescope.enable` | `false` | Wrap the game in Gamescope |
| `my.programs.steam.games.<name>.gamescope.width` / `.height` | `0` | Internal resolution for Gamescope |
| `my.programs.steam.games.<name>.gamescope.refreshRate` | `null` | Refresh rate limit for Gamescope |
| `my.programs.steam.games.<name>.gamescope.fullscreen` | `true` | Start in fullscreen mode |
| `my.programs.steam.games.<name>.gamescope.adaptiveSync` | `false` | Enable adaptive sync / VRR |
| `my.programs.steam.games.<name>.gamescope.extraArgs` | `[]` | Extra Gamescope arguments |

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

## Related Modules

- **Imported by** [`modules/nixos/common.nix`](../common.nix) — enabled on all hosts via `my.*` options.
