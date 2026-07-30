# Lutris

Lutris game manager and library for GNU/Linux.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.programs.lutris.enable` | `false` | Enable Lutris and related tools |
| `my.programs.lutris.gamemode.enable` | `true` | Enable Feral Gamemode |
| `my.programs.lutris.mangohud.enable` | `false` | Install MangoHud overlay |
| `my.programs.lutris.gamescope.enable` | `false` | Install Gamescope micro-compositor |
| `my.programs.lutris.gamescope.openFirewall` | `false` | Open ports for Gamescope streaming |
| `my.programs.lutris.battlenet.enable` | `false` | Battle.net support via Lutris + Wine WoW64 |
| `my.programs.lutris.battlenet.wine.package` | `wineWow64Packages.stable` | Wine package for Battle.net |
| `my.programs.lutris.battlenet.winetricks.enable` | `true` | Install winetricks |
| `my.programs.lutris.battlenet.protonup.enable` | `false` | Install protonup-ng for Wine-GE |
| `my.programs.lutris.battlenet.settings.esync` | `true` | Eventfd synchronization |
| `my.programs.lutris.battlenet.settings.fsync` | `true` | Futex synchronization |
| `my.programs.lutris.battlenet.settings.dxvk` | `true` | DXVK for DirectX 9-11 |
| `my.programs.lutris.battlenet.settings.vkd3d` | `true` | VKD3D for DirectX 12 |
| `my.programs.lutris.battlenet.settings.overrides` | `{ dwrite = "n"; }` | WINEDLLOVERRIDES |
| `my.programs.lutris.battlenet.settings.env` | *(see below)* | Environment variables |
| `my.programs.lutris.battlenet.gamescope.enable` | `false` | Wrap in Gamescope for Wayland |
| `my.programs.lutris.battlenet.gamescope.*` | — | Gamescope sizing/display options |
| `my.programs.lutris.extraPackages` | `[]` | Extra packages to install |

## Usage

```nix
my.programs.lutris = {
  enable = true;
  mangohud.enable = true;
  battlenet.enable = true;
};
```

Or via the gaming profile:

```nix
my.profiles.gaming.enable = true;
```

## Battle.net

### First-time install

1. Run `battlenet` or open Lutris
2. Click **+** → search **Battle.net**
3. Lutris will install it using system Wine (WoW64)
4. After install, launch via `battlenet` or the desktop entry

### Fixing invisible windows on Wayland

If Battle.net launches but no window appears (common on GNOME Wayland):

1. **Enable Gamescope**: `battlenet.gamescope.enable = true` — wraps Battle.net
   in Gamescope which manages its own XWayland, bypassing Mutter's quirks.
   Launch with `battlenet-gamescope`.

2. **Environment variables** are already set by default:
   - `SDL_VIDEODRIVER=x11` — forces XWayland for CEF rendering
   - `WINEESYNC=1` / `WINEFSYNC=1` — kernel-level sync primitives
   - `DXVK_HUD=0` — disables DXVK overlay

3. **In Battle.net settings** (if you can see the window): disable hardware
   acceleration (Options → General → Hardware Acceleration).

### Troublehsooting

| Symptom | Fix |
|---------|-----|
| Install freezes at ~25% | Missing 32-bit Vulkan — enable `my.profiles.gpu.mesa` or ensure `hardware.opengl.driSupport32Bit` |
| Spinning icon / no login | Disable hardware acceleration in Battle.net settings |
| JSON parse error | Transient — the installer writes config mid-flight, retry |
| "Wine runner needs to be installed" | Ensure `battlenet.enable = true` installs `wineWow64Packages.stable` |

## Notes

- Lutris requires 32-bit support and Vulkan — the gaming profile enables these.
- The `battlenet` CLI command sets all required env vars automatically.
- Gamescope can be used per-game in Lutris runner options as well.
