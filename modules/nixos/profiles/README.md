# Profiles

System and home profiles for easy host configuration.

## System Profiles

| Profile | Description |
|---------|-------------|
| `my.profiles.workstation` | Desktop/laptop with GUI |
| `my.profiles.server` | Headless server |
| `my.profiles.minimal` | Bare essentials |
| `my.profiles.gaming` | Gaming setup |
| `my.profiles.media` | Media stack (Prowlarr, Sonarr, Radarr, Jellyfin) |
| `my.profiles.entertainment` | Entertainment (gaming, music, media services) |
| `my.profiles.development` | Dev tools |
| `my.profiles.ai` | AI frontends (RisuAI, Open WebUI, Letta, Jan) |
| `my.profiles.desktop.choice` | Desktop-environment selection (`null`/`"hyprland"`/`"gnome"`) |
| `my.profiles.desktop.hyprland` | Hyprland Wayland compositor |
| `my.profiles.desktop.gnome` | GNOME desktop |
| `my.profiles.gpu.mesa` | Intel/AMD graphics |
| `my.profiles.gpu.nvidia` | NVIDIA graphics |
| `my.profiles.gpu.nvidia-headless` | NVIDIA headless/CUDA |
| `my.profiles.battery` | Power management |
| `my.profiles.location` | Timezone/geolocation |
| `my.profiles.testing` | Module smoke tests and health checks |
| `my.profiles.power.desktop` | Desktop power profile (never sleep, no lock) |
| `my.profiles.power.laptop` | Laptop power profile (battery-aware, lock on idle) |
| `my.profiles.theming.stylix` | Stylix theming framework |

## Home Profiles

| Profile | Description |
|---------|-------------|
| `my.homeProfiles.common` | Basic shell tools |
| `my.homeProfiles.desktop` | GUI applications |
| `my.homeProfiles.development` | Dev tools |
| `my.homeProfiles.server` | Server user |
| `my.homeProfiles.minimal` | Essential only |

## Usage

```nix
my.profiles = {
  workstation.enable = true;
  desktop.gnome.enable = true;
  gpu.mesa.enable = true;
};
```

## Related Modules

- **Imported by** [`modules/nixos/common.nix`](../common.nix) — enabled on all hosts via `my.*` options.
