# Sonarr

TV show automatic download and management. Integrates with Prowlarr for indexer access.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.sonarr.enable` | `false` | Enable Sonarr |
| `my.services.sonarr.port` | `8989` | Web UI port |
| `my.services.sonarr.openFirewall` | `false` | Open firewall port |
| `my.services.sonarr.disableAnalytics` | `true` | Disable telemetry |

## Usage

```nix
my.services.sonarr = {
  enable = true;
  openFirewall = true;
};
```

## Notes

- Uses upstream `services.sonarr` NixOS module.
- Point Prowlarr at Sonarr for auto-synced indexers.
