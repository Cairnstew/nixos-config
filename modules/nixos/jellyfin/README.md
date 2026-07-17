# Jellyfin

Media server for streaming movies, TV shows, and music. The front-end media player that serves content acquired by Sonarr/Radarr.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.jellyfin.enable` | `false` | Enable Jellyfin |
| `my.services.jellyfin.openFirewall` | `false` | Open firewall port |
| `my.services.jellyfin.mediaDirs` | `[]` | Directories to grant read access (e.g. `/mnt/media/movies`) |

## Usage

```nix
my.services.jellyfin = {
  enable = true;
  openFirewall = true;
  mediaDirs = [ "/mnt/media/movies" "/mnt/media/tv" ];
};
```

## Notes

- Uses upstream `services.jellyfin` NixOS module.
- Hardware transcoding config is available via `services.jellyfin.hardwareAcceleration.*` directly.
