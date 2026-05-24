# Profiles

System and home profiles for easy host configuration.

## System Profiles

| Profile | Description |
|---------|-------------|
| `my.profiles.workstation` | Desktop/laptop with GUI |
| `my.profiles.server` | Headless server |
| `my.profiles.minimal` | Bare essentials |
| `my.profiles.development` | Dev tools |
| `my.profiles.gaming` | Gaming setup |
| `my.profiles.desktop.gnome` | GNOME desktop |
| `my.profiles.desktop.plasma` | KDE Plasma |
| `my.profiles.gpu.mesa` | Intel/AMD graphics |
| `my.profiles.gpu.nvidia` | NVIDIA graphics |
| `my.profiles.gpu.nvidia-headless` | NVIDIA headless/CUDA |
| `my.profiles.battery` | Power management |
| `my.profiles.location` | Timezone/geolocation |

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
