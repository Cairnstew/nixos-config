# Hearthstone

Native Linux Hearthstone launcher using `hearthstone-linux-gui` (DawnMagnet).
No Wine, no Battle.net launcher, no Lutris.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.programs.hearthstone.enable` | `false` | Enable native Hearthstone |
| `my.programs.hearthstone.package` | `flake input` | Custom package override |
| `my.programs.hearthstone.dataDir` | `null` | Game data directory (e.g. `/mnt/media/hearthstone`) |

## Usage

```nix
my.programs.hearthstone.enable = true;
```

Or via the gaming profile:

```nix
my.profiles.gaming.enable = true;
```

## Notes

- Uses the `hearthstone-linux-gui` flake which wraps the game in an FHS
  environment with all required Unity dependencies.
- On the first run, click "Install" to download Hearthstone game data.
- Login via the Battle.net OAuth page (opens in the launcher's webview).
- If the login webview is blank on Wayland, `WEBKIT_DISABLE_DMABUF_RENDERER=1`
  is set by default to work around WebKitGTK + Wayland issues.
- Works on both GNOME Wayland and Hyprland.
