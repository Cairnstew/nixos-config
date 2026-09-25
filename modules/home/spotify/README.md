# Spotify

Spotify desktop client with optional TUI alternative and Waybar now-playing widget.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `my.programs.spotify.enable` | bool | false | Enable Spotify |
| `my.programs.spotify.package` | package | `pkgs.spotify` | Spotify desktop package |
| `my.programs.spotify.tui.enable` | bool | false | Enable spotatui TUI client |
| `my.programs.spotify.tui.package` | package | `pkgs.spotatui` | TUI package |
| `my.programs.spotify.tui.settings` | attrs | `{}` | TUI config (~/.config/spotatui/config.yml) |
| `my.programs.spotify.player.enable` | bool | false | Enable Waybar now-playing widget |
| `my.programs.spotify.player.interval` | int | 5 | Polling interval in seconds |
| `my.programs.spotify.player.package` | package | python3+spotipy | Python env for the widget |
| `my.programs.spotify.player.credentialsFile` | path | null | Credential file sourced before running |

## Usage

### Desktop client

```nix
my.programs.spotify.enable = true;
```

### TUI client

```nix
my.programs.spotify = {
  enable = true;
  tui.enable = true;
  tui.settings = {
    behavior = {
      enable_discord_rpc = false;
    };
  };
};
```

### Waybar now-playing widget

Enables a `spotify-now-playing` script that outputs waybar-compatible JSON
with the currently playing track. Add it to your waybar custom modules:

```nix
my.programs.spotify = {
  enable = true;
  player.enable = true;
  # Optional: source credentials from a file
  player.credentialsFile = "/run/secrets/spotify-cred";
};
```

Then register it in your waybar config:

```nix
my.desktop.hyprland.bar.customModules.spotify-now-playing = {
  exec = "spotify-now-playing";
  interval = 5;
  returnType = "json";
  tooltip = true;
  position = "right";
};
```

The widget outputs:
- **text**: ` ♫ Artist — Track`
- **tooltip**: Track name, artist, album, progress, device
- **class**: `playing` or `paused` (for CSS styling)
- **on-click**: Opens Spotify OAuth in browser if not authenticated, opens Spotify desktop if authenticated

### CSS styling

Add to your waybar style:

```css
#custom-spotify-now-playing { padding: 0 10px; color: #1db954; }
#custom-spotify-now-playing.paused { color: #6c7086; }
```

## Dependencies

- **Home Manager modules**: home.packages, home.file
- **Flake inputs**: none
- **System packages**: `spotipy` (Python)

## Development

The now-playing widget uses the `spotify-playlist-manager` Python package
for Spotify API interaction. If the Spotify API changes or you need to
fix/add features to the widget, use the **opencode ensemble space** to work
directly in the `spotify-playlist-manager` source:

```
team_spawn(
  name="fix",
  space="spotify-playlist-manager",
  prompt="fix the issue with ...",
  worktree=false
)
```

The `spotify-playlist-manager` space is cloned to
`~/.config/opencode/ensemble-spaces/spotify-playlist-manager/` on first use.
After pushing fixes upstream, update the local package or flake input.

## Notes

- This is a **Home Manager module**, not a NixOS module.
- When `tui.enable = true`, the TUI package (`spotatui`) is installed instead of the desktop client.
- TUI settings are written to `~/.config/spotatui/config.yml` as YAML.
- The player widget requires Spotify API credentials (client ID + redirect URI).
- Credentials can be provided via `player.credentialsFile` or already in the environment.
