# Spotify

Spotify desktop client with optional TUI alternative.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `my.programs.spotify.enable` | bool | false | Enable Spotify |
| `my.programs.spotify.package` | package | `pkgs.spotify` | Spotify desktop package |
| `my.programs.spotify.tui.enable` | bool | false | Enable spotatui TUI client |
| `my.programs.spotify.tui.package` | package | `pkgs.spotatui` | TUI package |
| `my.programs.spotify.tui.settings` | attrs | `{}` | TUI config (~/.config/spotatui/config.yml) |

## Usage

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

## Dependencies

- **Home Manager modules**: home.packages, home.file
- **Flake inputs**: none

## Notes

- This is a **Home Manager module**, not a NixOS module.
- When `tui.enable = true`, the TUI package (`spotatui`) is installed instead of the desktop client.
- TUI settings are written to `~/.config/spotatui/config.yml` as YAML.
