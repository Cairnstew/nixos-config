# GNOME Desktop

GNOME desktop environment with GDM, fonts, and home-manager integration.

## Options

> Scope note: the `my.desktop.gnome.*` desktop-options set (everything below except
> `enable`) is declared in **home-manager scope** in `home.nix`, which is imported via
> `home-manager.sharedModules` in `config.nix`. The NixOS-scope `options.nix` declares
> only `my.desktop.gnome.enable`. Defaults below reflect `home.nix`.

| Option | Default | Description |
|--------|---------|-------------|
| `my.desktop.gnome.enable` | `false` | Enable GNOME (NixOS scope; also gates the HM config) |
| `my.desktop.gnome.favoriteApps` | `[str]` | Favorite applications in GNOME dash |
| `my.desktop.gnome.workspaceNames` | `["Main"]` | Names for GNOME workspaces |
| `my.desktop.gnome.enableHotCorners` | `false` | Enable GNOME hot corners |
| `my.desktop.gnome.backgroundImage` | str | Background image (light mode) |
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
