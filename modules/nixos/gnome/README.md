# GNOME Desktop

GNOME desktop environment with GDM, fonts, and home-manager integration.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.desktop.gnome.enable` | `false` | Enable GNOME |
| `my.desktop.gnome.favoriteApps` | `[str]` | Favorite applications in GNOME dash |
| `my.desktop.gnome.workspaceNames` | `["Main"]` | Names for GNOME workspaces |
| `my.desktop.gnome.wayland` | `true` | Enable Wayland session in GDM (set `false` to force X11 in VMs) |
| `my.desktop.gnome.enableHotCorners` | `true` | Enable GNOME hot corners |
| `my.desktop.gnome.backgroundImage` | path | Background image (light mode) |
| `my.desktop.gnome.gtkTheme` | `"Breeze-Dark"` | GTK theme name (dark-mode aware) |
| `my.desktop.gnome.iconTheme` | `"Papirus-Dark"` | Icon theme name (dark-mode aware) |
| `my.desktop.gnome.cursorTheme` | `"Adwaita"` | Cursor theme name |
| `my.desktop.gnome.fontName` | `"Inter 11"` | Default UI font |
| `my.desktop.gnome.fontMonospace` | str | Monospace font (terminal font + size) |
| `my.desktop.gnome.numWorkspaces` | `4` | Number of static workspaces |

## Usage

```nix
my.desktop.gnome.enable = true;
```

## Related Modules

- **Imported by** [`modules/nixos/common.nix`](../common.nix) — enabled on all hosts via `my.*` options.
